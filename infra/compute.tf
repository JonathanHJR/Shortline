resource "aws_iam_role" "ec2_role" {
  name = "shortline-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Lets you shell in via SSM Session Manager, without opening port 22 at all.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Scoped to pulling exactly this one ECR repo — same least-privilege
# pattern as iam/ecr-policy.json, just for the instance instead of CI.
# Because this runs via the instance's own IAM role, there's no token
# to manually refresh (unlike platform/'s local kind cluster, which
# uses a temporary secret that expires every 12h).
resource "aws_iam_role_policy" "ecr_pull" {
  name = "shortline-ecr-pull"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "GetAuthToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "PullShortlineRepo"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:910929919817:repository/shortline"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "shortline-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Referencing aws_ecr_repository.shortline.repository_url (rather than a
  # hardcoded string) also makes Terraform wait until the repo actually
  # exists before booting an instance that needs to pull from it.
  user_data = <<-EOF
    #!/bin/bash
    yum install -y docker
    systemctl start docker
    aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin 910929919817.dkr.ecr.${var.aws_region}.amazonaws.com
    docker run -d -p ${var.app_port}:${var.app_port} -e PORT=${var.app_port} ${aws_ecr_repository.shortline.repository_url}:latest
  EOF

  tags = { Name = "shortline" }
}

output "public_ip" {
  value = aws_instance.app.public_ip
}

output "app_url" {
  value = "http://${aws_instance.app.public_ip}:${var.app_port}"
}
