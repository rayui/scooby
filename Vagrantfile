$script = <<-SCRIPT
  apt update -y
  apt install -y curl
  curl -sL get.hashi-up.dev | sh
  hashi-up packer get -d /usr/local/bin
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bullseye64"
  config.vm.boot_timeout = 600
  config.ssh.forward_env = ["LC_HOSTNAME","LC_DEFAULT_USER","LC_EXTERNAL_DEVICE","LC_EXTERNAL_IP","LC_EXTERNAL_NET","LC_PRIMARY_DNS","LC_EXTERNAL_DOMAIN","LC_EXTERNAL_GW","LC_SECONDARY_DNS","LC_INTERNAL_IP","LC_INTERNAL_NET","LC_INTERNAL_DEVICE","LC_INTERNAL_DOMAIN","LC_SSH_AUTH_KEY","LC_IMAGE_HREF","LC_IMAGE_SHA"]

  config.vm.provider "virtualbox" do |vb|
    vb.customize [ "modifyvm", :id, "--uartmode1", "disconnected" ]
    vb.memory = 8192
    vb.cpus = 4
  end

  config.vm.provision "shell", inline: $script
end
