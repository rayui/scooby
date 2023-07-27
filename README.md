# Scooby

## Self-hosting RPi K3S cluster

### Services

This project requires the following services to build:

- Github and Github Actions
- Vagrant
- Packer

### Packer

You will need a URI for base linux image (and SHA) for Packer to create the bootable images. I use:

- http://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-01-28/2022-01-28-raspios-bullseye-arm64-lite.zip
- sha256:d694d2838018cf0d152fe81031dba83182cee79f785c033844b520d222ac12f5

### Building locally

You will need the following environment variables set in a .env file in the project root

- LC_DEFAULT_USER
  - name of your default user for the cluster
- LC_EXTERNAL_DEVICE
  - your external facing device (e.g. eth0)
- LC_EXTERNAL_IP
  - the public ip v4 address of your cluster
- LC_EXTERNAL_NET
  - network and netmask of your cluster nic, e.g. 192.168.1.0/24
- LC_EXTERNAL_DNS
  - external DNS provider, e.g. 1.0.0.1
- LC_EXTERNAL_DOMAIN
  - domain on external nic - the domain of your lan
- LC_EXTERNAL_GW
  - public gateway of your lan
- LC_LOCAL_DNS
  - local dns provider, e.g 192.168.1.66
- LC_INTERNAL_IP
  - the private ip v4 address of your cluster
- LC_INTERNAL_NET
  - network and netmask of your cluster nic, e.g. 192.168.64.0/24
- LC_INTERNAL_DEVICE
  - the internal device name for your cluster (e.g. eth1)
- LC_INTERNAL_DOMAIN
  - the internal domain name of your cluster, (e.g. sunnydale)
- PACKER_GITHUB_API_TOKEN
  - your Packer API token
- SSH_AUTH_KEY
  - your SSH auth key to access the cluster
- LC_IMAGE_HREF
  - the HREF to node linux your base image
- LC_IMAGE_SHA
  - the SHA for your base node linux image

Build the project by running

`./scripts/build.sh`

The output disk image will be found in `./images/scooby.img`

### Github Actions

Once you have cloned this project, you must create several Github Action environment secrets and variables, as follows:

#### Secrets

- LC_DEFAULT_USER
  - name of your default user for the cluster
- LC_EXTERNAL_DEVICE
  - your external facing device (e.g. eth0)
- LC_EXTERNAL_IP
  - the public ip v4 address of your cluster
- LC_EXTERNAL_NET
  - network mask of your external nic, e.g. 24
- LC_EXTERNAL_DNS
  - external DNS provider, e.g. 1.0.0.1
- LC_EXTERNAL_DOMAIN
  - domain on external nic - the domain of your lan
- LC_EXTERNAL_GW
  - public gateway of your lan
- LC_LOCAL_DNS
  - local dns provider, e.g 192.168.1.66
- LC_INTERNAL_IP
  - the private ip v4 address of your cluster
- LC_INTERNAL_NET
  - network mask of your cluster nic, e.g. 24
- LC_INTERNAL_DEVICE
  - the internal device name for your cluster (e.g. eth1)
- LC_INTERNAL_DOMAIN
  - the internal domain name of your cluster, (e.g. sunnydale)
- PACKER_GITHUB_API_TOKEN
  - your Packer API token
- SSH_AUTH_KEY
  - your SSH auth key to access the cluster

#### Variables

- LC_IMAGE_HREF
  - the HREF to your base node linux image
- LC_IMAGE_SHA
  - the SHA for your base node linux image

### Server config

Any files placed in the `/server` directory will be copied into the image as static assets. They are persistent and available on first boot.

Kubernetes manifests should go in `/server/var/lib/k3s/server/manifests`

Also included is a udev script to reset 8152 USB network interfaces and an example dnsmasq dhcp service.

### Agent config

The server configuration step will create one agent instance for each directory in `/server/etc/scooby/agents/{hostname}`. Each agent directory must have the following files with contents as described:

- `ethernet` - the mac address of the agent
- `ip` - the ipv4 address of the agent
- `rancher_partition_uuid` - partition uuid of local storage for k3s agent. This could be e.g. sd card or usb storage
- `tftp_client_id` - the tftp id of the client. You can find the client id of any RPi with: `cat /sys/firmware/devicetree/base/serial-number`

If there are no complete agent definitions, the server will be the only node in the cluster.

### Vagrant

This project requires Vagrant. I use a self-hosted runner, which is more work to set up but much cheaper.

If you wish to use Github's own runners, you will need to edit `./github/workflows/build.yml` to use OSX as only it has Vagrant by default:

`runs-on: macos-latest`
