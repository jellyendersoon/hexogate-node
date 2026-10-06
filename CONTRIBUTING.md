# Contributing to Hexogate Node

- Open an issue describing the problem or the change before larger work.
- Keep the panel-facing contract stable: do not rename the protobuf package, the gRPC service or the REST routes, and do not change the reported node version format.
- Run `gofmt -l .`, `go vet ./...` and `go test ./...` before opening a pull request. Integration tests need the Xray binary (`bash scripts/install_xray.sh`) and the test certificates (`make generate_server_cert generate_client_cert`).
- If you edit `common/service.proto`, regenerate with `make generate_grpc_code` using the tool versions listed in the README and commit the generated files.
