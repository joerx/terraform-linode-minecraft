# Minecraft on Linode

Terraform module to deploy Minecraft servers on Linode using a Stackscript. This repo contains two modules, one to deploy the shared stackscript and one to deploy the server instances themselves. You can download the modules from the releases page.

## Prerequisites

Terraform, `jq` and a recent version of the [`Github CLI`](https://cli.github.com/) are required.

## Usage

See [example](./example/)

## Releasing

Use the `release` target to create a GH release. This will trigger the workflow to publish release assets.

```sh
make release VERSION=v0.1.0
```

## Development

### Tests

To run the tests for each module:

```sh
make test
```

### Development Servers

#### Prerequisites

- Obtain your current public IP, e.g. using https://whatismyipaddress.com/

Backup Storage:

- Linode account, OSS bucket name and S3 endpoints for the development environment
- Use https://github.com/joerx/terraform-linode-bucket to create the bucket

Grafana Cloud:

- A free-tier Grafana Cloud account is required to run this example
- Get the Grafana Cloud API key and hosted logs/metrics IDs

#### Local Server (QEMU)

- On a linux host, a local development server can be created using [`libvirt`](https://libvirt.org/)
- This assumes a working setup of `libvirt`, [KVM](https://en.wikipedia.org/wiki/Kernel-based_Virtual_Machine) and [QEMU](https://www.qemu.org/) - A good intro can be found [here](https://joshrosso.com/docs/2020/2020-05-06-linux-hypervisor-setup/)
- This allows rapid iteration of build and init scripts locally & is cheaper to run than a cloud instance
- Create a `dev.tfvars` file with some basic credentials (see above)
- Set `enabled=false` to avoid creating the actual server instance in the cloud 💸

```sh
cat <<EOF > ./example/dev.tfvars
gcloud_rw_api_key="<your-api-key-here>"
gcloud_hosted_logs_id="<your-hosted-logs-id-here>"
gcloud_hosted_metrics_id="<your-hosted-metrics-id-here>"
bucket_name="<backup-bucket-name-here>"
s3_endpoint="eu-central-1.linodeobjects.com"
ingress=["$(curl -sS https://api.ipify.org?format=json | jq -r '.ip')/32"]
enabled=false
EOF
```

- The base images themselves are here: https://github.com/joerx/packer-linode-minecraft - Clone the repo locally and follow the instructions to build a QEMU based image for local testing (Take note of the output path)
- Change into the example directory and run `local-server.sh` to run a local development server:

```sh
cd example
./local-server.sh create <path-to-my-image> # Create the VM
./local-server.sh ssh # Login, may need to retry a few times
```

#### Cloud Based Test Servers

- To run the test server in the cloud instead of locally, simply set `enabled=true` in `example/dev.tfvars`, then:

```sh
cd example
terraform apply -var-file dev.tfvars
```

- To connect via SSH:

```sh
PUBLIC_IP=$(terraform output -raw public_ip)
terraform output -raw private_key_pem | ssh-add -
ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" ubuntu@$PUBLIC_IP
```
