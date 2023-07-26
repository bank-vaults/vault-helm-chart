# Vault Helm chart

[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/bank-vaults/vault-helm-chart/ci.yaml?style=flat-square)](https://github.com/bank-vaults/vault-helm-chart/actions/workflows/ci.yaml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/bank-vaults/vault-helm-chart/badge?style=flat-square)](https://api.securityscorecards.dev/projects/github.com/bank-vaults/vault-helm-chart)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/vault)](https://artifacthub.io/packages/search?repo=vault)

**A Helm chart for installing Hashicorp Vault .**

## Development

**For an optimal developer experience, it is recommended to install [Nix](https://nixos.org/download.html) and [direnv](https://direnv.net/docs/installation.html).**

_Alternatively, install [Go](https://go.dev/dl/) on your computer then run `make deps` to install the rest of the dependencies._

Make sure Docker is installed with Compose and Buildx.

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

## License

The project is licensed under the [Apache 2.0 License](LICENSE).
