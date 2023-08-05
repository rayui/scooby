# Scooby

## Self-hosting RPi K3S cluster

Scooby is a template for building repeatable bare-metal Kubernetes clusters. It has an opinionated architecture where the Kubernetes master acts as a network gateway for the agent subnet of zero or more nodes.

All you need to get going is at least one Raspberry Pi 3A or higher, a network and a USB storage device.

Features:

- Statically configured
- Repeatable, hands-off deployments
- Network booted agents - no local storage for OS required
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
`LC_PRIMARY_DNS` external DNS provider, e.g. 1.0.0.1  
`LC_SECONDARY_DNS` local dns provider, e.g 192.168.1.66 (optional)  
`LC_EXTERNAL_DEVICE` your external facing device (e.g. eth0)  
`LC_EXTERNAL_IP` the public ip v4 address of your cluster  
`LC_EXTERNAL_NET` network and netmask of your cluster nic, e.g. 192.168.1.0/24  
`LC_EXTERNAL_GW` public gateway of your lan, e.g. 192.168.1.1  
`LC_EXTERNAL_DOMAIN` domain on external nic the domain of your lan  
`LC_INTERNAL_DEVICE` the internal device name for your cluster (e.g. eth1)  
`LC_INTERNAL_IP` the private ip v4 address of your cluster  
`LC_INTERNAL_NET` network and netmask of your cluster nic, e.g. 192.168.64. 0/24  
`LC_INTERNAL_DOMAIN` the internal domain name of your cluster, (e.g. sunnydale)  
`LC_IMAGE_HREF` the HREF to node linux your base image  
`LC_IMAGE_SHA` the SHA for your base node linux image

#### Default values

It is possible to build the cluster using only default values, however it is recommended to provide them all in your own `config` file as they are currently subject to change.

```
LC_HOSTNAME=buffy
LC_DEFAULT_USER=spike
LC_PRIMARY_DNS=1.0.0.1
LC_SECONDARY_DNS=
LC_EXTERNAL_DEVICE=eth0
LC_EXTERNAL_IP=192.168.1.64
LC_EXTERNAL_NET=192.168.1.0/24
LC_EXTERNAL_DOMAIN=
LC_EXTERNAL_GW=192.168.1.1
LC_INTERNAL_IP=192.168.64.1
LC_INTERNAL_NET=192.168.64.0/24
LC_INTERNAL_DEVICE=eth1
LC_INTERNAL_DOMAIN=sunnydale
LC_IMAGE_HREF="http://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-01-28/2022-01-28-raspios-bullseye-arm64-lite.zip"
LC_IMAGE_SHA=sha256:d694d2838018cf0d152fe81031dba83182cee79f785c033844b520d222ac12f5

```

### Build

Build the project locally by running

`./scripts/build.sh`

The output disk image will be found in `./images/scooby.img`

### Building with Github Actions

Once you have cloned this project, populate the ci build action's variables and secrets in Github project settings.
Build the project by merging a commit to `main`.
If you have the AWS secrets set, GHA will attempt to upload your image to an S3 bucket of your choice.

### GHA only secrets

`AWS_ACCESS_KEY_ID` the Key ID for your AWS account  
`AWS_SECRET_ACCESS_KEY` the Secret Access Key for your AWS account  
`AWS_BUCKET_S3_URI` the S3 URI for your bucket account  
`AWS_REGION` the AWS region in which your bucket is located

### Runners

A self-hosted runner is recommended if you plan to make frequent changes.
If you wish to use Github's own runners, you will need to edit `./github/workflows/build.yml` and change `runs-on` to `macos-latest`.

## Server config

Any files placed in the `/server` directory will be copied into the image as static assets. They are persistent and available on first boot.

Kubernetes manifests should go in `/server/var/lib/rancher/k3s/server/manifests`

## Agent config

On build, the server configuration step will create one agent instance for each directory in `/server/etc/scooby/agents/{hostname}.agent`. Agents are described in the `agents` folder in the project root. Create one file for each agent node. The name of the file is the hostname of the agent node. The required variables are:

`AGENT_ETHERNET`, `AGENT_IP`, `AGENT_RANCHER_PART_UUID`, `AGENT_PXE_ID`

An optional variable, `AGENT_K3S_ARGS`, allows you to provide extra arguments to the K3S agent.

An example agent description file might look like the following:

```
AGENT_ETHERNET=b8:27:eb:81:1a:52
AGENT_IP=192.168.64.65
AGENT_RANCHER_PART_UUID=d5f9e6c2-493c-48da-baf2-0c63dd7a36b1
AGENT_PXE_ID=c6811a52
AGENT_K3S_ARGS="--node-label 'smarter-device-manager=enabled'"
```

You can find the PXE client id of any Raspberry Pi with the following command on the client console:

```
$ cat /sys/firmware/devicetree/base/serial-number
```

An incomplete or incorrect agent description will not result in a bootable agent node.
