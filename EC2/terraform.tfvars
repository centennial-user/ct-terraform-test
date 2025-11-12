/*
	Removed AWS credentials from this file to avoid committing secrets.
	Recommended options to provide credentials to Terraform:
	- Use environment variables in PowerShell:
			$env:AWS_ACCESS_KEY_ID = "AKIA..."
			$env:AWS_SECRET_ACCESS_KEY = "..."
	- Use the AWS credentials file at %USERPROFILE%\.aws\credentials and set AWS_PROFILE
	- Use your CI or secret manager (Terraform Cloud, Vault, GitHub Actions secrets)

	If you prefer to keep local credentials for testing, store them in a file that is
	ignored by git (and never commit). Example: create 'local-secrets.tfvars' and add
	it to .gitignore.
*/

aws_region = "us-east-1"
name_prefix = "venkat"
vpc_cidr = "10.10.0.0/16"
instance_type = "m5.large"
key_name = "ct-keypair"
common_tags = {
  Owner = "venkat"
  Env   = "dev"
}
subnets = [
  { name = "public-1", cidr = "10.10.0.0/24", map_public_ip_on_launch = true },
  { name = "private-1", cidr = "10.10.1.0/24" }
]
create_nat = true
enable_ssm_endpoints = true
