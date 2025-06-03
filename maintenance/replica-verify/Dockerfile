FROM litestream/litestream:latest

RUN apk update && \
    apk add --no-cache fish sqlite curl && \
    rm -f /tmp/* /etc/apk/cache/*

COPY entrypoint.fish /app/entrypoint.fish

ENTRYPOINT ["/usr/bin/fish"]
CMD ["/app/entrypoint.fish"]
