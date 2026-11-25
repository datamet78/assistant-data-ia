# =============================================================================
# INFRA — main.tf
# -----------------------------------------------------------------------------
# Étape 1 : une seule ressource « métier », le bucket du data lake.
# But : valider la chaîne complète GitHub -> pipeline -> AWS.
# Les zones bronze/, silver/ et gold/ seront des PRÉFIXES (des « dossiers »)
# dans ce bucket ; on les remplira à l'étape 2.
# =============================================================================

data "aws_caller_identity" "current" {}

locals {
  # Même convention que le bootstrap : "dataia-<numéro de compte>".
  prefix = "${var.project}-${data.aws_caller_identity.current.account_id}"
}

# --- Le bucket ---------------------------------------------------------------
resource "aws_s3_bucket" "lake" {
  # Le nom commence par "<prefix>-lake" : c'est exactement ce que le rôle
  # apply a le droit de gérer (voir bootstrap/main.tf, politique "deploy").
  bucket = "${local.prefix}-lake"
}

# --- Versioning : protège contre les suppressions/écrasements accidentels ----
# Exemple : une ingestion boguée écrase un fichier bronze -> on récupère la
# version précédente. C'est aussi un élément du plan de reprise après panne.
resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- Chiffrement au repos (SSE-S3, gratuit) ---------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- Aucun accès public, jamais ----------------------------------------------
resource "aws_s3_bucket_public_access_block" "lake" {
  bucket                  = aws_s3_bucket.lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Cycle de vie : maîtrise des coûts --------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id

  rule {
    id     = "nettoyage"
    status = "Enabled"
    filter {} # s'applique à tout le bucket

    # Un envoi de gros fichier interrompu laisse des morceaux invisibles...
    # mais facturés. On les supprime après 7 jours.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # Le versioning garde les anciennes versions indéfiniment :
    # on les supprime 30 jours après leur remplacement.
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# --- Politique du bucket : HTTPS obligatoire --------------------------------
# Même principe que pour le bucket du state : tout accès non chiffré en
# transit est refusé.
data "aws_iam_policy_document" "lake_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.lake.arn,
      "${aws_s3_bucket.lake.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "lake" {
  bucket = aws_s3_bucket.lake.id
  policy = data.aws_iam_policy_document.lake_tls_only.json

  # Ordre explicite : on applique d'abord le blocage d'accès public, puis la
  # politique. Évite une erreur de « course » entre les deux appels d'API.
  depends_on = [aws_s3_bucket_public_access_block.lake]
}
