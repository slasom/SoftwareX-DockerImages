###Dockerfile dium
FROM docker.io/crazymax/diun:latest

COPY kubectl /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl

RUN apk update && \
     	apk add curl && \
     	apk add skopeo

