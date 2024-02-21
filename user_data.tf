data "template_file" "bastion_server_setup" {
  #https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file
  template = file("${path.module}/user_data/bastion_server_setup.tpl")
}