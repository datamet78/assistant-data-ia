# =============================================================================
# BOOTSTRAP — versions.tf
# -----------------------------------------------------------------------------
# Ce dossier est appliqué UNE SEULE FOIS, depuis ton poste, avec tes propres
# identifiants AWS (un utilisateur administrateur ou IAM Identity Center).
#
# Pourquoi pas par le pipeline ? Parce qu'il crée justement ce dont le
# pipeline a besoin pour fonctionner : le bucket du state, la connexion OIDC
# et les rôles IAM. C'est le problème de « l'œuf et la poule ».
# =============================================================================

terraform {
  # Terraform 1.10 minimum : c'est la version qui permet de verrouiller le
  # state directement dans S3 (use_lockfile), sans table DynamoDB.
  required_version = ">= 1.10"

  required_providers {
    # Le « provider » est le plugin qui sait parler à l'API AWS.
    # "~> 6.0" = n'importe quelle version 6.x, mais pas la 7 (qui pourrait
    # casser la compatibilité).
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Pas de bloc "backend" ici : le state du bootstrap reste en local, dans
  # bootstrap/terraform.tfstate (exclu de git par .gitignore).
  # ⚠️ Ne supprime pas ce fichier : sans lui, Terraform « oublie » qu'il a
  # créé ces ressources. Garde-en une copie en lieu sûr.
}

provider "aws" {
  region = var.region

  # Tags ajoutés automatiquement à toutes les ressources créées.
  # Utile pour filtrer les coûts par projet dans Cost Explorer.
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform-bootstrap"
    }
  }
}
