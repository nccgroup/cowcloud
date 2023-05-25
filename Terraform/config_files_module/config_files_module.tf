
variable "config" { }
variable "setup" {}

data "template_file" "config_template" {
  template = "${file("${path.module}/config.tpl")}"
  vars = var.config
}

output "config_files_output" {
  value       = "${data.template_file.config_template.rendered}"
}


data "template_file" "setup_win_template" {
  template = "${file("${path.module}/setup-win.tpl")}"
  vars = var.setup
}

output "setup_win_config_output" {
  value       = "${data.template_file.setup_win_template.rendered}"
}


data "template_file" "setup_nix_template" {
  template = "${file("${path.module}/setup-nix.tpl")}"
  vars = var.setup
}

output "setup_nix_config_output" {
  value       = "${data.template_file.setup_nix_template.rendered}"
}
