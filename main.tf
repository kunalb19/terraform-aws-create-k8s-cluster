module "create_control_plane" {
  source                      = "kmayer10/create-ec2/aws"
  version                     = "1.0.1"
  ami                         = var.control_plane.ami
  instance_type               = var.control_plane.instance_type
  key_name                    = var.control_plane.key_name
  associate_public_ip_address = var.control_plane.associate_public_ip_address
  vpc_security_group_ids      = var.control_plane.vpc_security_group_ids
  subnet_id                   = var.control_plane.subnet_id
  tags                        = var.control_plane.tags
  user_data                   = var.control_plane.user_data
  private_key_file            = var.control_plane.private_key_file
  private_key                 = var.control_plane.private_key
}

resource "null_resource" "create_join_command_on_control_plane" {
  provisioner "remote-exec" {
    inline = [
      "sudo kubeadm token create --print-join-command > /tmp/join_command.sh",
      "chmod 600 ~/.ssh/id_rsa",
      "sudo apt-get install -y ansible",
      "echo [defaults] > /home/${var.control_plane.user}/.ansible.cfg",
      "echo host_key_checking = False >> /home/${var.control_plane.user}/.ansible.cfg",
      "mkdir -p /home/${var.control_plane.user}/.kube",
      "sudo cp /etc/kubernetes/admin.conf /home/${var.control_plane.user}/.kube/config",
      "sudo chown ${var.control_plane.user}:${var.control_plane.user} /home/${var.control_plane.user}/.kube/config",
      "sudo chmod 644 /home/${var.control_plane.user}/.kube/config"
    ]
    connection {
      type        = "ssh"
      host        = module.create_control_plane.instance_public_ip
      user        = var.control_plane.user
      private_key = var.control_plane.private_key
    }
  }
}

resource "null_resource" "fetch_kubeconfig_from_control_plane_to_local" {
  depends_on = [
    null_resource.create_join_command_on_control_plane 
  ]
  provisioner "local-exec" {
    command = "scp -i ${var.control_plane.private_key_file} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${var.control_plane.user}@${module.create_control_plane.instance_public_ip}:/home/${var.control_plane.user}/.kube/config ./config"
  }
}