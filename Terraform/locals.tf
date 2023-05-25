resource "random_string" "randn" {
  length  = 8
  upper = false
  special = false
  lifecycle {
    ignore_changes = all
  }
}


locals {
  accountId = data.aws_caller_identity.current.account_id
  s3bucket_scans = "scans-storage-${random_string.randn.result}-cowcloud"
  s3bucket_name_website = "website-${random_string.randn.result}-cowcloud"
  s3bucket_name_ec2repository = "ec2py-repo-${random_string.randn.result}-cowcloud"

  myregion = "us-east-1"

  config = {
    URL = module.gateway_module.invoke_url
    REGION = local.myregion
    USER_POOL_ID = module.cognito_module.aws_cognito_user_pool_id
    APP_CLIENT_ID= module.cognito_module.aws_cognito_user_pool_client_id
    DOMAIN= "cogn1to-domain-${random_string.randn.result}-cowcloud"
    REDIRECT_SIGN_IN= "${local.schema_http}://${module.cloudfront_module.aws_cloudfront_distribution_domain_name}" # FOR DEBUGGING PURPOSE "http://localhost"
    REDIRECT_SIGN_OUT= "${local.schema_http}://${module.cloudfront_module.aws_cloudfront_distribution_domain_name}" # FOR DEBUGGING PURPOSE "http://localhost"
    S3BUCKET_NAME_WEBSITE = "${local.s3bucket_name_website}"
    CLOUDFRONT_DISTRIBUTION_ID = "${module.cloudfront_module.cloudfront_distribution_id}"
    S3BUCKET_EC2APP_REPO = "${local.s3bucket_name_ec2repository}"
  }

  setup = {
    S3BUCKET_NAME_WEBSITE = "${local.s3bucket_name_website}"
    CLOUDFRONT_DISTRIBUTION_ID = "${module.cloudfront_module.cloudfront_distribution_id}"
    S3BUCKET_EC2APP_REPO = "${local.s3bucket_name_ec2repository}"
  }

  debug_domain = "localhost"
  schema_http = "https" # when debugging domain is set, then this should be http rather than https

}

