FROM golang:1.15.2-buster

ARG GH_VERSION='1.2.0'

RUN apt-get update \
    && apt-get -y install \
        rpm \
        gnupg2 \
        gpg-agent \
        debsigs \
        unzip \
        zip \
    && go get golang.org/dl/go1.9.7 \
    && /go/bin/go1.9.7 download

RUN curl -L https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.deb -o gh_${GH_VERSION}_linux_amd64.deb
RUN dpkg -i gh_${GH_VERSION}_linux_amd64.deb
