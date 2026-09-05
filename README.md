# grpc-protocol

CLOS gRPC protocol for cl-stack. **Not** JSON-RPC — that is [`rpc-protocol`](https://github.com/egao1980/rpc-protocol).

Part of [cl-stack](https://github.com/egao1980/cl-stack) agent-wire ([brief](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/grpc.md)).

```lisp
(asdf:load-system "grpc-backend-native")   ; binds *grpc-backend*

(let ((ch (grpc-protocol:grpc-connect "localhost:50051" :credentials :insecure)))
  (unwind-protect
       (grpc-protocol:grpc-call ch "/pkg.Svc/Ping" request-octets)
    (grpc-protocol:grpc-close ch)))
```

Streaming: `grpc-stream` → `grpc-send` / `grpc-recv` / `grpc-close`.

`:compression` on `grpc-connect` / `grpc-call` / `grpc-stream` is `:gzip` or
`:deflate` (or `nil`). Stashed as metadata `:compression` — not a wire header.
[`grpc-backend-http2`](https://github.com/egao1980/grpc-backend-http2) **0.3.1**
frames with flag 1 and sets `grpc-encoding`. Native C-core ignores it.

Messages are proto objects or octets. Codec is [`protobuf-protocol`](https://github.com/egao1980/protobuf-protocol). Pass `:response-class` in `metadata` to decode.

`grpc-error` carries `:status` (`:unavailable`, `:unimplemented`, …) plus `:details`.

CI: canned [`cl-repository`](https://github.com/egao1980/cl-repository) (`test-system.yml` / `setup-client` + `ci`). Deps from `ghcr.io/egao1980/cl-systems`.

## License

MIT
