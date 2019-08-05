FROM alpine:latest

# test
RUN apk --no-cache --no-progress add curl groff jq mysql-client python && \
    curl "https://bootstrap.pypa.io/get-pip.py" | python && \
    pip install awscli
