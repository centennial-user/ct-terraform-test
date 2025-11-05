variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}
variable "aws_s3" {
  type        = string
  description = "S3 bucket for terraform state"
  default     = "centennial-tf-state"
}
variable "aws_dynamodb_table" {
  type        = string
  description = "DynamoDB table for terraform state locking"
  default     = "ct-tf-locks"
}