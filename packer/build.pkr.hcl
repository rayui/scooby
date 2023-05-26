variable "ssh_auth_key" {
  type = string
}

variable "default_user" {
  type = string
}

build {
  sources = [
    "source.arm-image.raspios_bullseye_arm64"
  ]

  provisioner "shell" {
    scripts = [
      "scripts/install-cloud-init.sh"
    ]
    environment_vars = ["SSH_AUTH_KEY=${var.ssh_auth_key}", "DEFAULT_USER=${var.default_user}"]
  }
}
