# Scooby

## Self-hosting RPi K3S cluster

Scooby is a template for building repeatable bare-metal Kubernetes clusters. It has an opinionated architecture where the Kubernetes master acts as a network gateway for the agent subnet of zero or more nodes.

All you need to get going is at least one Raspberry Pi 3A or higher, a network and a USB storage device.

Features:

- Statically configured
- Network booted agents
- Automated build pipelines for GHA and local development
- Build, deploy and boot a bare-metal cluster from source in 15 minutes

### Build requirements

- Vagrant
- Github Actions (optional)

### Setting up

You will need to set the secret environment variables in a file called `.env` in the project root.
Everything else is configuration you wish to commit. This goes in a file called `config` in the project root.
You can build a bootable instance without the variables marked optional, although they are recommended.

#### Secret environment variables

`LC_DEFAULT_USER` name of your default user for the cluster  
`LC_SSH_AUTH_KEY` your SSH auth key to access the cluster (optional)  
`LC_PACKER_GITHUB_API_TOKEN` your Packer API token (optional)

#### Everything else

`LC_HOSTNAME` hostname of the server  
`LC_EXTERNAL_DEVICE` your external facing device (e.g. eth0)  
`LC_EXTERNAL_IP` the public ip v4 address of your cluster  
`LC_EXTERNAL_NET` network and netmask of your cluster nic, e.g. 192.168.1.0/24  
`LC_EXTERNAL_DNS` external DNS provider, e.g. 1.0.0.1  
`LC_EXTERNAL_DOMAIN` domain on external nic the domain of your lan  
`LC_EXTERNAL_GW` public gateway of your lan  
`LC_LOCAL_DNS` local dns provider, e.g 192.168.1.66 (optional)  
`LC_INTERNAL_IP` the private ip v4 address of your cluster  
`LC_INTERNAL_NET` network and netmask of your cluster nic, e.g. 192.168.64. 0/24
`LC_INTERNAL_DEVICE` the internal device name for your cluster (e.g. eth1)  
`LC_INTERNAL_DOMAIN` the internal domain name of your cluster, (e.g. sunnydale)
`LC_IMAGE_HREF` the HREF to node linux your base image  
`LC_IMAGE_SHA` the SHA for your base node linux image

#### Recommended values

`LC_IMAGE_HREF`: `http://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-01-28/2022-01-28-raspios-bullseye-arm64-lite.zip`
`LC_IMAGE_SHA`: `sha256:d694d2838018cf0d152fe81031dba83182cee79f785c033844b520d222ac12f5`

### Build

Build the project locally by running

`./scripts/build.sh`

The output disk image will be found in `./images/scooby.img`

### Building with Github Actions

Once you have cloned this project, populate the ci build action's variables and secrets in Github project settings.

### Runners

A self-hosted runner is recommended if you plan to make frequent changes.
If you wish to use Github's own runners, you will need to edit `./github/workflows/build.yml` and change `runs-on` to `macos-latest`.

## Server config

Any files placed in the `/server` directory will be copied into the image as static assets. They are persistent and available on first boot.

Kubernetes manifests should go in `/server/var/lib/k3s/server/manifests`

## Agent config

The server configuration step will create one agent instance for each directory in `/server/etc/scooby/agents/{hostname}`. Each agent directory must have the following files with contents as described:

- `ethernet` - the mac address of the agent
- `ip` - the ipv4 address of the agent
- `rancher_partition_uuid` - partition uuid of local storage for k3s agent. This could be e.g. sd card or usb storage
- `tftp_client_id` - the tftp id of the client. You can find the client id of any RPi with: `cat /sys/firmware/devicetree/base/serial-number`

If there are no complete agent definitions, the server will be the only node in the cluster.
