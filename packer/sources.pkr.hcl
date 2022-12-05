source "arm-image" "raspios_bullseye_arm64" {
  image_type      = "raspberrypi"
  iso_url         = "http://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-01-28/2022-01-28-raspios-bullseye-arm64-lite.zip"
  iso_checksum    = "sha256:d694d2838018cf0d152fe81031dba83182cee79f785c033844b520d222ac12f5"
  output_filename = "images/rpi-cloud-init-raspios-bullseye-arm64.img"
  qemu_binary     = "qemu-aarch64-static"
}
