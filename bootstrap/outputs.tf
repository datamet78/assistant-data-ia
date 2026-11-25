# =============================================================================
# BOOTSTRAP — outputs.tf
# -----------------------------------------------------------------------------
# Les "outputs" s'affichent à la fin de "terraform apply" (et à tout moment
# avec "terraform output"). Ces 4 valeurs sont à copier dans GitHub :
#   Settings > Secrets and variables > Actions > onglet "Variables"
# Ce sont des variables, pas des secrets : un ARN de rôle n'est pas une clé,
# il ne donne aucun accès sans le jeton OIDC de ton dépôt.
# =============================================================================

output "tf_state_bucket" {
  description = "Variable GitHub TF_STATE_BUCKET."
  value       = aws_s3_bucket.tfstate.bucket
}

output "plan_role_arn" {
  description = "Variable GitHub AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.github_plan.arn
}

output "apply_role_arn" {
  description = "Variable GitHub AWS_APPLY_ROLE_ARN."
  value       = aws_iam_role.github_apply.arn
}

output "region" {
  description = "Variable GitHub AWS_REGION."
  value       = var.region
}
