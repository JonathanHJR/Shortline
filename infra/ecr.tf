# Owned here (not created manually/out-of-band) specifically so that
# terraform destroy tears this down along with everything else — same
# reasoning as capstone's eks.tf comment on the OIDC provider: anything
# created outside Terraform's tracking doesn't get cleaned up with the
# rest, and quietly lingers (and, for a registry, quietly keeps costing
# storage) between sessions.
resource "aws_ecr_repository" "shortline" {
  name                 = "shortline"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.shortline.repository_url
}
