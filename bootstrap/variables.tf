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
  # eu-north-1 (Stockholm) : c'est la Région imposée par AWS aux comptes
  # « projet » européens (nouvelle expérience d'inscription). Elle doit
  # correspondre à la Région de ton projet, visible sur settings.aws.com.
  # Choix justifié dans docs/adr/0001-fondations.md.
  default = "eu-north-1"
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

# Identifiants NUMÉRIQUES du propriétaire et du dépôt sur GitHub.
# Depuis le 15 juillet 2026, les jetons OIDC des nouveaux dépôts les
# contiennent (format « immuable ») : un nom peut être réutilisé par
# quelqu'un d'autre après un renommage, un identifiant numérique jamais.
# Pour les trouver (dépôt public) :
#   curl -s https://api.github.com/repos/<owner>/<repo> | grep -m2 '"id":'
#   -> 1re ligne = id du dépôt, 2e ligne = id du propriétaire
variable "github_owner_id" {
  description = "Identifiant numérique du propriétaire GitHub."
  type        = string
}

variable "github_repo_id" {
  description = "Identifiant numérique du dépôt GitHub."
  type        = string
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
