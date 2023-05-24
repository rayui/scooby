variable "ssh_auth_key" {}

build {
  sources = [
    "source.arm-image.raspios_bullseye_arm64"
  ]

  provisioner "shell" {
    scripts = [
      "scripts/install-cloud-init.sh"
    ]
    environment_vars = ["SSH_AUTH_KEY=${var.ssh_auth_key}"]
  }
}
