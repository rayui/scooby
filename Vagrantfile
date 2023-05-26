$script = <<-SCRIPT
  apt update -y
  apt install -y curl
  curl -sL get.hashi-up.dev | sh
  hashi-up packer get -d /usr/local/bin
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bullseye64"
  config.vm.boot_timeout = 600
  config.ssh.forward_env = ["LC_SSH_AUTH_KEY", "LC_ALL", "LC_PACKER_GITHUB_API_TOKEN", "LC_IMAGE_HREF", "LC_IMAGE_SHA", "LC_EXTERNAL_IP", "LC_INTERNAL_IP", "LC_INTERNAL_DEVICE", "LC_DEFAULT_USER", "LC_AGENT_IMAGE_HREF"]

  config.vm.provider "virtualbox" do |vb|
    vb.customize [ "modifyvm", :id, "--uartmode1", "disconnected" ]
  end

  config.vm.provision "shell", inline: $script
end
