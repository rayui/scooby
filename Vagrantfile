$script = <<-SCRIPT
  apt update -y
  apt install -y curl
  curl -sL get.hashi-up.dev | sh
  hashi-up packer get -d /usr/local/bin
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bullseye64"
  config.vm.boot_timeout = 600
  config.ssh.forward_env = ["LC_DEFAULT_USER","LC_SSH_AUTH_KEY","LC_PACKER_GITHUB_API_TOKEN"]

  config.vm.provider "virtualbox" do |vb|
    vb.customize [ "modifyvm", :id, "--uartmode1", "disconnected" ]
    vb.memory = 8192
    vb.cpus = 4
  end

  config.vm.provision "shell", inline: $script
end
