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

