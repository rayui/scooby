$script = <<-SCRIPT
  apt update -y
  apt install -y curl
  rm /etc/default/locale
  curl -sL get.hashi-up.dev | sh
  hashi-up packer get -d /usr/local/bin
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bullseye64"
  config.vm.boot_timeout = 600
  config.ssh.forward_env = ["LC_SSH_AUTH_KEY", "LC_ALL", "LC_PACKER_GITHUB_API_TOKEN"]

  config.vm.provider "virtualbox" do |vb|
    vb.customize [ "modifyvm", :id, "--uartmode1", "disconnected" ]
  end

  config.vm.provision "shell", inline: $script
end
