# Vault Helm Chart

[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/bank-vaults/vault-helm-chart/ci.yaml?style=flat-square)](https://github.com/bank-vaults/vault-helm-chart/actions/workflows/ci.yaml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/bank-vaults/vault-helm-chart/badge?style=flat-square)](https://api.securityscorecards.dev/projects/github.com/bank-vaults/vault-helm-chart)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/8047/badge)](https://www.bestpractices.dev/projects/8047)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/vault)](https://artifacthub.io/packages/search?repo=vault)

**A Helm chart for installing [Hashicorp Vault](https://www.vaultproject.io/).**

## Development

**For an optimal developer experience, it is recommended to install [Nix](https://nixos.org/download.html) and [direnv](https://direnv.net/docs/installation.html).**

_Alternatively, install [Go](https://go.dev/dl/) on your computer then run `make deps` to install the rest of the dependencies._

Make sure Docker is installed with Compose and Buildx.

Fetch required tools:

```shell
make deps
```

Run project dependencies:

```shell
make up
```

Run the test suite:

```shell
make test-acceptance
```

Run linters:

```shell
make lint # pass -j option to run them in parallel
```

Build artifacts locally:

```shell
make artifacts
```

Once you are done, you can tear down project dependencies:

```shell
make down
```

## License

The project is licensed under the [Apache 2.0 License](LICENSE).
