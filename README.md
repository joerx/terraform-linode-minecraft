# Minecraft on Linode

Terraform module to deploy Minecraft servers on Linode using a Stackscript. This repo contains two modules, one to deploy the shared stackscript and one to deploy the server instances themselves. You can download the modules from the releases page.

## Prerequisites

Terraform, `jq` and a recent version of the [`Github CLI`](https://cli.github.com/) are required.

## Usage

TODO

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
