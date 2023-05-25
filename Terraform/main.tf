


module "cloudfront_module" {
  source ="./cloudfront_module"
  domain_name = module.s3bucket_module.aws_s3_bucket_website_domain_name
  cidr_whitelist = var.cidr_whitelist

}

# output "test" {

#   value=local.s3bucket_scans
# }

module "s3bucket_module" {
  source = "./s3bucket_module"
  s3bucket_name_results_storage = local.s3bucket_scans
  s3bucket_name_website = local.s3bucket_name_website
  s3bucket_name_ec2repository = local.s3bucket_name_ec2repository
  cidr_whitelist = var.cidr_whitelist
  cloudfront_origin_access_identity_iam_arn = module.cloudfront_module.cloudfront_origin_access_identity_iam_arn
  retention_time = var.retention_time
    
}

module "dynamodb_module" {
  source = "./dynamodb_module"
  autoscaling_arn = module.ec2_module.autoscaling_arn
  maximum_number_of_terminating_machines = var.maximum_number_of_terminating_machines
  max_queued_tasks_per_worker = var.max_queued_tasks_per_worker
  max_workers = var.max_workers
  retention_time = var.retention_time

}


module "step_functions_module" {
  source = "./step_functions_module"
  retention_time = var.retention_time

}

module "snssqs_module" {
  source = "./snssqs_module"
}


module "cognito_module" {
  source = "./cognito_module"
  domain = module.cloudfront_module.aws_cloudfront_distribution_domain_name
  #domain  = local.debug_domain # UNCOMMENT FOR DEBUGGING PURPOSE
  random_value = random_string.randn.result

  schema_http = local.schema_http

}

# Everytime you make a change here, you might need to destroy the deployment and apply again: terraform destroy -target module.gateway_module.aws_api_gateway_deployment.lambda --auto-approve
module "gateway_module" {
  source = "./gateway_module"
  accountId = local.accountId
  myregion = local.myregion
  domain = module.cloudfront_module.aws_cloudfront_distribution_domain_name
  # domain = local.debug_domain # UNCOMMENT FOR DEBUGGING PURPOSE

  schema_http = local.schema_http
  lambda_arn = module.lambda_module.lambda_arn
  lambda_arn_get_object = module.lambda_module.lambda_arn_get_object
  cognito_user_pool_name = module.cognito_module.cognito_user_pool_name
  cognito_pool_depends_on = module.cognito_module.cognito_pool_depends_on
  retention_time = var.retention_time
  cidr_whitelist = var.cidr_whitelist

}

module "lambda_module" {
  source = "./lambda_module"
  accountId = local.accountId
  myregion = local.myregion
  domain = module.cloudfront_module.aws_cloudfront_distribution_domain_name
  # domain  = local.debug_domain # UNCOMMENT FOR DEBUGGING PURPOSE

  schema_http = local.schema_http
  tasks_queue_arn = module.snssqs_module.tasks_queue_arn
  topic_task_arn = module.snssqs_module.topic_task_arn
  s3bucket_arn_results_storage = module.s3bucket_module.s3bucket_arn_results_storage
  s3bucket_name_results_storage = module.s3bucket_module.s3bucket_name_results_storage
  dynamodb_table_tasks_arn = module.dynamodb_module.dynamodb_table_tasks_arn
  dynamodb_table_workers_arn = module.dynamodb_module.dynamodb_table_workers_arn
  dynamodb_table_archive_arn = module.dynamodb_module.dynamodb_table_archive_arn
  aws_api_gateway_rest_api_id = module.gateway_module.aws_api_gateway_rest_api_id
  aws_api_gateway_resource_path_put_task = module.gateway_module.aws_api_gateway_resource_path_put_task
  http_method_put_task = module.gateway_module.http_method_put_task
  aws_api_gateway_resource_path_get_object = module.gateway_module.aws_api_gateway_resource_path_get_object
  http_method_get_object = module.gateway_module.http_method_get_object
  retention_time = var.retention_time

}

module "lambda_module_workers" {
  source = "./lambda_module_workers"
  dynamodb_table_tasks_arn = module.dynamodb_module.dynamodb_table_tasks_arn
  dynamodb_table_workers_arn = module.dynamodb_module.dynamodb_table_workers_arn
  dynamodb_table_archive_arn = module.dynamodb_module.dynamodb_table_archive_arn
  state_machine_arn = module.step_functions_module.state_machine_arn
  retention_time = var.retention_time

}

module "ec2_module" {
  source = "./ec2_module"
  lambda_arn_workers_manager = module.lambda_module_workers.lambda_arn_workers_manager
  myregion = local.myregion
  accountId = local.accountId
  tasks_queue_name = module.snssqs_module.tasks_queue_name
  tasks_queue_arn = module.snssqs_module.tasks_queue_arn
  s3bucket_name_results_storage = module.s3bucket_module.s3bucket_name_results_storage
  s3bucket_arn_results_storage = module.s3bucket_module.s3bucket_arn_results_storage
  s3bucket_name_ec2repository = module.s3bucket_module.s3bucket_name_ec2repository
  s3bucket_arn_ec2repository = module.s3bucket_module.s3bucket_arn_ec2repository
  heartbeat_timeout = var.heartbeat_timeout
  max_workers = var.max_workers
  maximum_number_of_terminating_machines = var.maximum_number_of_terminating_machines
  eipenable = var.eipenable
  ami = var.ami
  instance_type = var.instance_type
  cidr_whitelist = var.cidr_whitelist
  retention_time = var.retention_time
  dynamodb_table_tasks_arn = module.dynamodb_module.dynamodb_table_tasks_arn
  dynamodb_table_archive_arn = module.dynamodb_module.dynamodb_table_archive_arn
  

}

module "config_files" {
  source = "./config_files_module"
  config = local.config
  setup = local.setup

}

# output "config_files_output" {
#   value = module.config_files.config_files_output
# }

resource "local_file" "front_end_config" {
    content     = "${module.config_files.config_files_output}"
    filename = "config.js"
}

resource "local_file" "setup_win_config" {
    content     = "${module.config_files.setup_win_config_output}"
    filename = "setup.bat"
}

resource "local_file" "setup_nix_config" {
    content     = "${module.config_files.setup_nix_config_output}"
    filename = "setup.sh"
}

# to debug locally
output "manager_ini" {
  value = module.ec2_module.manager_ini
}

output "eips" {
  description = "Elastic ip address for cowCloud workers"
  value       = module.ec2_module.cowCloud_eips
}


output "website" {
  value = "${local.schema_http}://${module.cloudfront_module.aws_cloudfront_distribution_domain_name}"
}

