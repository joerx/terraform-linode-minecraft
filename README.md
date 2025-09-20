# Minecraft on Linode

Terraform module to deploy Minecraft servers on Linode using a Stackscript. This repo contains two modules, one to deploy the shared stackscript and one to deploy the server instances themselves. You can download the modules from the releases page.

## Prerequisites

Terraform, `jq` and a recent version of the [`Github CLI`](https://cli.github.com/) are required.

## Usage

See [example](./server/example/)

## Releasing

Use the `release` target to create a GH release. This will trigger the workflow to publish release assets.

```sh
make release VERSION=v0.1.0
```

## Development

To run the tests for each module:

```sh
make test MODULE=server
make test MODULE=stackscript
```

### Test Servers

- The [example](./server/example/) should be able to run a dev server with a random name
- It will use the shared development resources to store backups and handle DNS
- However, state will NOT be stored remotely, make sure to keep track of your local state file
- You need to create a `dev.tfvars` file with some basic credentials:

```sh
cat <<EOF > ./server/example/dev.tfvars
gcloud_rw_api_key="<your-api-key-here>"
gcloud_hosted_logs_id="<your-hosted-logs-id-here>"
gcloud_hosted_metrics_id="<your-hosted-metrics-id-here>"
bucket_name="<backup-bucket-name-here>"
s3_endpoint="eu-central-1.linodeobjects.com"
EOF
```

- To create the server:

```sh
cd server/example
terraform apply -var-file dev.tfvars
```

### Local Server

- On a linux host, a local development server based on [`libvirt`](https://libvirt.org/) is available
- This assumes a working setup of `libvirt`, [KVM](https://en.wikipedia.org/wiki/Kernel-based_Virtual_Machine) and [QEMU](https://www.qemu.org/), which is not covered here - a good intro can be found [here](https://joshrosso.com/docs/2020/2020-05-06-linux-hypervisor-setup/)
- This allows rapid iteration of the init scripts on a local machine, which is faster (and cheaper) than running a cloud server each time
- Configure the `dev.tfvars` file as above, but instead of `terraform apply` run:

```
cd server/example
./local-server.sh create # Create the VM
./local-server.sh login # Login
```
