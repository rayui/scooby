$script = <<-SCRIPT
  sudo apt update -y
  sudo apt install -y curl
  curl -sL get.hashi-up.dev | sudo sh
  sudo hashi-up packer get -d /usr/local/bin
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bullseye64"
  config.vm.boot_timeout = 600

  config.vm.provider "virtualbox" do |vb|
    vb.customize [ "modifyvm", :id, "--uartmode1", "disconnected" ]
  end

  config.vm.provision "shell", inline: $script
end
