# =============================================================================
# INFRA — variables.tf
# =============================================================================

variable "project" {
  description = "Nom court du projet. Doit être identique à celui du bootstrap, sinon le rôle apply n'aura pas les droits (ils sont filtrés sur ce préfixe)."
  type        = string
  default     = "dataia"
}

variable "region" {
  description = "Région AWS (la même que le bootstrap)."
  type        = string
  default     = "eu-north-1"
}
