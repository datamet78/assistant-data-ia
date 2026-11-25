# =============================================================================
# BOOTSTRAP — variables.tf
# -----------------------------------------------------------------------------
# Les variables sont les « paramètres » du code. Celles qui ont un "default"
# sont facultatives ; les autres doivent être renseignées dans
# terraform.tfvars (voir terraform.tfvars.example).
# =============================================================================

variable "project" {
  description = "Nom court du projet, utilisé comme préfixe des ressources."
  type        = string
  default     = "dataia"
}

variable "region" {
  description = "Région AWS. Europe pour respecter le RGPD."
  type        = string
  # eu-west-1 (Irlande) : la région européenne qui reçoit en général les
  # nouveaux services (Bedrock, S3 Vectors...) en premier. Choix justifié
  # dans docs/adr/0001-fondations.md.
  default = "eu-west-1"
}

variable "github_owner" {
  description = "Propriétaire du dépôt GitHub (ton nom d'utilisateur)."
  type        = string
}

variable "github_repo" {
  description = "Nom du dépôt GitHub."
  type        = string
  default     = "assistant-data-ia"
}

variable "alert_email" {
  description = "Adresse e-mail qui reçoit les alertes budget."
  type        = string
}

variable "budget_usd" {
  description = "Budget mensuel en dollars."
  type        = number
  default     = 10
}
