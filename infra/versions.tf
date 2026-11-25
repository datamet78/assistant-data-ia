# =============================================================================
# INFRA — versions.tf
# -----------------------------------------------------------------------------
# Ce dossier est déployé par le PIPELINE (GitHub Actions), pas à la main.
# Il contiendra toute l'infrastructure applicative du projet, étape par étape.
# =============================================================================

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Le state est stocké dans le bucket créé par le bootstrap.
  #
  # Configuration « partielle » : le nom du bucket contient ton numéro de
  # compte, on ne l'écrit donc pas en dur. Il est fourni au moment du
  # "terraform init" :
  #   - dans le pipeline : via la variable GitHub TF_STATE_BUCKET
  #   - en local         : via le fichier backend.hcl (voir l'exemple)
  backend "s3" {
    key          = "infra/terraform.tfstate" # chemin du fichier dans le bucket
    encrypt      = true                      # chiffré dans S3
    use_lockfile = true                      # verrou natif S3 (Terraform ≥ 1.10)
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Repo      = "assistant-data-ia"
    }
  }
}
