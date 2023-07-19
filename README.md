# Scooby

## Self-hosting RPi K3S cluster

### Services

This project requires the following services to build:

- AWS S3
- Github and Github Actions
- Vagrant
- Packer

### AWS S3 Bucket

You must first create a bucket in which to store your generated images. You will need the S3 URI of this bucket, as well as your key id, your secret access key and your bucket region.

### Packer

You will need a URI for base linux image (and SHA) for Packer to create the bootable images. I use:

- http://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-01-28/2022-01-28-raspios-bullseye-arm64-lite.zip
- sha256:d694d2838018cf0d152fe81031dba83182cee79f785c033844b520d222ac12f5

### Github Actions

Once you have cloned this project, you must create several Github Action environment secrets and variables, as follows:

#### Secrets

- AWS_BUCKET_S3_URI
  - the S3 URI bucket for generated images
- AWS_KEY_ID
  - your AWS key ID
- AWS_SECRET_ACCESS_KEY
  - you AWS secret access key
- AWS_REGION
  - your AWS bucket region
- LC_DEFAULT_USER
  - name of your default user
- LC_EXTERNAL_IP
  - the public ip v4 address of your cluster
- LC_EXTERNAL_NM
  - network mask of your external nic
- LC_INTERNAL_IP
  - the private ip v4 address of your cluster
- LC_INTERNAL_NM
  - network mask of your cluster nic
- LC_INTERNAL_DEVICE
  - the internal device name for your cluster (e.g. eth1)
- LC_EXTERNAL_DNS
  - external DNS provider, e.g. 1.0.0.1
- LC_EXTERNAL_DOMAIN
  - domain on external nic - the domain of your lan
- LC_EXTERNAL_GW

  - public gateway of your lan

- LC_LOCAL_DNS

- PACKER_GITHUB_API_TOKEN
  - your Packer API token
- SSH_AUTH_KEY
  - your public SSH key to access the cluster

#### Variables

- LC_IMAGE_HREF
  - the HREF to your base image
- LC_IMAGE_SHA
  - the SHA for your base image

### Vagrant

This project requires Vagrant. I use a self-hosted runner, which is more work to set up but much cheaper.

If you wish to use Github's own runners, you will need to edit `./github/workflows/build.yml` to use OSX as only it has Vagrant by default:

`runs-on: macos-latest`
