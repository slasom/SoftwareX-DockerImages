FROM alpine:latest

RUN apk add --no-cache bash curl jq

COPY clean-registry.sh /scripts/clean-registry.sh

RUN chmod +x /scripts/clean-registry.sh

ENTRYPOINT ["/scripts/clean-registry.sh"]

