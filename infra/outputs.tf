# =============================================================================
# INFRA — outputs.tf
# Valeurs affichées après le déploiement (et réutilisables à l'étape 2).
# =============================================================================

output "lake_bucket" {
  description = "Nom du bucket du data lake."
  value       = aws_s3_bucket.lake.bucket
}
