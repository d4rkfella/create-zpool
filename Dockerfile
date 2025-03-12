FROM alpine:3.21

RUN apk add --no-cache cosign crane bash curl

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
