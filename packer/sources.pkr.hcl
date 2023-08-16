variable "image_href" {
  type = string
}

variable "image_sha" {
  type = string
}

source "arm-image" "raspios_bullseye_arm64" {
  image_type      = "raspberrypi"
  iso_url         = "${var.image_href}"
  iso_checksum    = "${var.image_sha}"
  output_filename = "images/scooby.img"
  qemu_binary     = "qemu-aarch64-static"
}
