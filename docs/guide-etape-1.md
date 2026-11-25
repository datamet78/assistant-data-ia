# Guide pas à pas — Étape 1 : fondations

Durée estimée : 2 à 3 heures la première fois.

## 0. Prérequis sur ton poste
| Outil | Vérifier avec | Installation |
|---|---|---|
| Git | `git --version` | git-scm.com |
| Terraform ≥ 1.10 | `terraform version` | developer.hashicorp.com/terraform/install |
| AWS CLI v2 | `aws --version` | docs.aws.amazon.com/cli |
| Python 3.12+ | `python3 --version` | python.org |

Tu as aussi besoin d'un compte AWS et d'un compte GitHub.

## 1. Se connecter à AWS en local
Pour le bootstrap, il te faut des identifiants **administrateur**, qui ne doivent pas être ceux de l'utilisateur root. La méthode recommandée est IAM Identity Center :
```bash
aws configure sso          # suivre les questions ; nom de profil : dataia-admin
aws sso login --profile dataia-admin
export AWS_PROFILE=dataia-admin
aws sts get-caller-identity   # doit afficher ton numéro de compte
```

## 2. Créer le dépôt GitHub
1. Sur GitHub, crée un dépôt **vide** nommé `assistant-data-ia` (public si tu veux le montrer).
2. En local, dans le dossier du projet :
```bash
git init -b main
git add .
git commit -m "Étape 1 : fondations"
git remote add origin https://github.com/<ton-compte>/assistant-data-ia.git
```
Ne pousse pas encore : le pipeline échouerait, car AWS n'est pas prêt.

## 3. Appliquer le bootstrap
```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# édite terraform.tfvars : ton compte GitHub et ton e-mail
terraform init
terraform plan      # lis ce qui va être créé (une quinzaine de ressources)
terraform apply     # tape "yes"
terraform output    # note les 4 valeurs affichées
```
- 📧 Tu ne reçois pas d'e-mail de confirmation pour le budget. Les alertes arriveront directement.
- 💾 Sauvegarde `bootstrap/terraform.tfstate` hors du dépôt, dans un endroit sûr.

## 4. Renseigner les variables dans GitHub
Va dans *Settings > Secrets and variables > Actions*, onglet **Variables**, puis *New repository variable* :

| Nom | Valeur (issue de `terraform output`) |
|---|---|
| `AWS_REGION` | `region` |
| `TF_STATE_BUCKET` | `tf_state_bucket` |
| `AWS_PLAN_ROLE_ARN` | `plan_role_arn` |
| `AWS_APPLY_ROLE_ARN` | `apply_role_arn` |

## 5. Premier déploiement
```bash
cd ..
git push -u origin main
```
Dans l'onglet **Actions**, tu dois voir le job `Tests Python` passer, puis `Terraform apply`. Vérifie ensuite dans la console S3 que le bucket `dataia-<compte>-lake` existe.

## 6. Tester le circuit complet avec une pull request
```bash
git checkout -b test/pipeline
# modifie quelque chose d'anodin, ex. ajoute un tag dans infra/versions.tf :
#   Owner = "ton-prenom"
git commit -am "Test : ajout d'un tag"
git push -u origin test/pipeline
```
1. Ouvre la pull request sur GitHub.
2. Regarde le job `Terraform plan` : son *Summary* doit annoncer des tags modifiés et aucune destruction.
3. Fusionne la PR : `Terraform apply` se déclenche alors sur `main`.

## 7. Protéger la branche main (recommandé)
Va dans *Settings > Branches > Add branch ruleset* (ou *Branch protection rule*) pour `main` :
- exiger une pull request avant de fusionner ;
- exiger que les vérifications `Tests Python` et `Terraform plan` passent.

## ✅ Critères de fin d'étape
- [ ] Le bootstrap est appliqué et son state est sauvegardé.
- [ ] Une PR affiche un plan, et sa fusion déclenche un apply réussi.
- [ ] Le bucket du lake existe, chiffré et sans accès public.
- [ ] Aucune clé AWS ne figure dans GitHub.
- [ ] Tu sais expliquer en 2 minutes le flux OIDC et la différence entre les rôles plan et apply.

## En cas de problème
| Erreur | Cause probable |
|---|---|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | `github_owner` ou `github_repo` mal renseigné dans le bootstrap (attention à la casse), ou variable GitHub erronée. |
| `AccessDenied` pendant l'apply | Ressource dont le nom ne commence pas par `dataia-<compte>-lake`, ou `project` différent entre bootstrap et infra. |
| `terraform fmt -check` échoue | Lance `terraform fmt -recursive` et recommite. |
| `ruff format --check` échoue | Lance `ruff format .` et recommite. |
| `Error acquiring the state lock` | Un autre pipeline tourne : attends. S'il a planté, `terraform force-unlock <ID>` en local. |

## Coût de cette étape
Il est proche de 0 $ : le bucket est vide, le budget est gratuit, et GitHub Actions est gratuit pour les dépôts publics (2 000 minutes par mois pour les dépôts privés).
