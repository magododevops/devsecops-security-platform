FROM golang:1.25-alpine AS builder

WORKDIR /src

COPY go.mod ./
COPY cmd/ ./cmd/
COPY internal/ ./internal/

RUN CGO_ENABLED=0 GOOS=linux \
    go build -trimpath \
    -ldflags="-s -w" \
    -o /out/server ./cmd/server

FROM scratch

COPY --from=builder /out/server /server

USER 65532:65532

EXPOSE 8080

ENTRYPOINT ["/server"]
