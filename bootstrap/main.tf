# =============================================================================
# BOOTSTRAP — main.tf
# -----------------------------------------------------------------------------
# Trois briques :
#   1. Le bucket S3 qui stocke le state Terraform du projet
#   2. La fédération OIDC GitHub -> AWS + deux rôles IAM (plan / apply)
#   3. L'alerte budget
# =============================================================================

# Un "data source" LIT une information existante sans rien créer.
# Ici : le numéro de ton compte AWS (12 chiffres).
data "aws_caller_identity" "current" {}

# Les "locals" sont des valeurs calculées, réutilisées plus bas.
locals {
  account_id = data.aws_caller_identity.current.account_id

  # Les noms de bucket S3 sont uniques AU MONDE. Ajouter le numéro de compte
  # évite les collisions : ex. "dataia-123456789012-tfstate".
  prefix = "${var.project}-${local.account_id}"

  # Préfixe du "sujet" (sub) des jetons OIDC émis par GitHub pour ton dépôt.
  # Format immuable (dépôts créés après le 15 juillet 2026) :
  #   repo:<propriétaire>@<id propriétaire>/<dépôt>@<id dépôt>
  # ex. "repo:datamet78@12345678/assistant-data-ia@987654321"
  # (L'ancien format, sans les @id, ne correspond plus aux jetons reçus.)
  repo = "${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}"

  # Chemin du fichier de state de infra/ dans le bucket
  # (doit correspondre au "key" de infra/versions.tf).
  state_key = "infra/terraform.tfstate"
}

# =============================================================================
# 1. BUCKET DU STATE TERRAFORM
# -----------------------------------------------------------------------------
# Le state est le fichier où Terraform note ce qu'il a créé (identifiants,
# attributs...). Il peut contenir des informations sensibles : on le chiffre,
# on le versionne et on bloque tout accès public.
# =============================================================================

resource "aws_s3_bucket" "tfstate" {
  bucket = "${local.prefix}-tfstate"

  # Garde-fou : Terraform refusera de détruire ce bucket, même avec
  # "terraform destroy". Le perdre, c'est perdre la mémoire de l'infra.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning : chaque écriture du state garde l'ancienne version.
# Si un state est corrompu, on peut revenir en arrière.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Chiffrement au repos avec SSE-S3 (clés gérées par AWS).
# Gratuit, contrairement à une clé KMS dédiée (~1 $/mois par clé).
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Blocage de tout accès public : les 4 interrupteurs à "true".
# (AWS l'active par défaut sur les nouveaux buckets, mais l'écrire dans le
# code rend la règle explicite et visible en revue.)
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Cycle de vie : les anciennes versions du state sont supprimées après
# 90 jours, pour que le versioning ne fasse pas grossir la facture.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    id     = "anciennes-versions"
    status = "Enabled"
    filter {} # filtre vide = s'applique à tout le bucket
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# "aws_iam_policy_document" génère du JSON de politique IAM à partir d'une
# syntaxe Terraform, plus lisible et vérifiée à l'écriture.
#
# Cette politique REFUSE toute requête non chiffrée (HTTP au lieu de HTTPS).
# Un "Deny" l'emporte toujours sur un "Allow" dans IAM.
data "aws_iam_policy_document" "tfstate_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.tfstate.arn,        # le bucket lui-même
      "${aws_s3_bucket.tfstate.arn}/*", # tous les objets qu'il contient
    ]
    principals {
      type        = "*"
      identifiers = ["*"] # tout le monde
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"] # ... dès que la connexion n'est pas en TLS
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate_tls_only.json
}

# =============================================================================
# 2. FÉDÉRATION OIDC GITHUB -> AWS
# -----------------------------------------------------------------------------
# Principe : à chaque exécution, GitHub Actions reçoit un jeton signé (JWT)
# qui dit « je suis le workflow du dépôt X, sur la branche Y ». AWS vérifie
# la signature et, si les conditions du rôle sont remplies, donne des
# identifiants TEMPORAIRES (1 h max).
#
# Résultat : aucune clé d'accès AWS stockée dans GitHub, donc rien à voler
# et rien à faire tourner.
# =============================================================================

# Déclare GitHub comme fournisseur d'identité de confiance dans ton compte.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  # "audience" attendue dans le jeton : c'est la valeur qu'utilise l'action
  # officielle aws-actions/configure-aws-credentials.
  client_id_list = ["sts.amazonaws.com"]

  # thumbprint_list n'est plus nécessaire : AWS vérifie le certificat de
  # GitHub avec ses propres autorités de certification.
}

# ---------------------------------------------------------------------------
# Politique de confiance (trust policy) du rôle "plan".
# Elle répond à la question : QUI a le droit d'endosser ce rôle ?
# Réponse : les workflows de TON dépôt, sur une pull request ou sur main.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "trust_plan" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Le jeton doit être destiné à AWS STS...
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # ... et provenir de ton dépôt. Le champ "sub" (sujet) du jeton vaut
    # par exemple "repo:alice@111/assistant-data-ia@222:pull_request".
    # Sans cette condition, N'IMPORTE QUEL dépôt GitHub pourrait endosser
    # le rôle : c'est l'erreur de configuration OIDC la plus courante.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.repo}:pull_request",
        "repo:${local.repo}:ref:refs/heads/main",
      ]
    }
  }
}

# ---------------------------------------------------------------------------
# Politique de confiance du rôle "apply" : UNIQUEMENT la branche main.
# Une pull request (même la tienne) ne peut donc jamais modifier l'infra :
# il faut que le code ait été relu et fusionné.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "trust_apply" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals" # égalité stricte, pas de joker
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "${var.project}-github-plan"
  assume_role_policy   = data.aws_iam_policy_document.trust_plan.json
  max_session_duration = 3600 # identifiants valables 1 h maximum
}

resource "aws_iam_role" "github_apply" {
  name                 = "${var.project}-github-apply"
  assume_role_policy   = data.aws_iam_policy_document.trust_apply.json
  max_session_duration = 3600
}

# ---------------------------------------------------------------------------
# Permissions : QUE peut faire chaque rôle une fois endossé ?
# ---------------------------------------------------------------------------

# Accès au state, commun aux deux rôles. Le rôle "plan" a aussi besoin
# d'écrire : il pose un verrou (fichier .tflock) pendant son exécution pour
# éviter que deux Terraform modifient le state en même temps.
data "aws_iam_policy_document" "state_access" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }
  statement {
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    # Limité au state de infra/ et à son verrou : pas d'accès au reste.
    resources = [
      "${aws_s3_bucket.tfstate.arn}/${local.state_key}",
      "${aws_s3_bucket.tfstate.arn}/${local.state_key}.tflock",
    ]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "terraform-state"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.state_access.json
}

resource "aws_iam_role_policy" "apply_state" {
  name   = "terraform-state"
  role   = aws_iam_role.github_apply.id
  policy = data.aws_iam_policy_document.state_access.json
}

# Rôle "plan" : lecture seule sur le compte (politique gérée par AWS).
# "terraform plan" doit lire l'état réel des ressources pour le comparer
# au code. Compromis assumé : ReadOnlyAccess est large (cf. ADR 0001).
resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Rôle "apply" : droits de déploiement limités aux ressources du projet,
# reconnues à leur nom ("dataia-<compte>-lake...").
#
# Ces droits s'élargiront à chaque étape (Lambda, Glue, Athena, Bedrock...),
# mais TOUJOURS ici, dans le bootstrap appliqué à la main. Ainsi, le
# pipeline ne peut jamais s'accorder lui-même de nouveaux droits.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid     = "ProjectBuckets"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${local.prefix}-lake*",
      "arn:aws:s3:::${local.prefix}-lake*/*",
    ]
  }
}

resource "aws_iam_role_policy" "apply_deploy" {
  name   = "deploy"
  role   = aws_iam_role.github_apply.id
  policy = data.aws_iam_policy_document.deploy.json
}

# =============================================================================
# 3. ALERTE BUDGET
# -----------------------------------------------------------------------------
# AWS Budgets envoie un e-mail quand les dépenses dépassent un seuil.
# ⚠️ C'est une ALERTE, pas un plafond : AWS ne coupe rien automatiquement.
# Les deux premiers budgets d'un compte sont gratuits.
# =============================================================================

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-mensuel"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_usd) # l'API attend une chaîne
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Alerte n°1 : 50 % du budget réellement dépensé (5 $).
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # Alerte n°2 : 80 % réellement dépensé (8 $).
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # Alerte n°3 : AWS PRÉVOIT de dépasser 100 % d'ici la fin du mois.
  # C'est la plus utile : elle prévient avant que le mal soit fait.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
