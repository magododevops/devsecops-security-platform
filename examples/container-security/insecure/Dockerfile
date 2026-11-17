# Intentionally insecure - isolated lab only
FROM ubuntu:latest

ENV APP_ENV=development

RUN apt-get update && \
    apt-get install -y curl

WORKDIR /app

COPY . /app

USER root

CMD ["/bin/bash"]
