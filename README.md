[![Build container(s) & Upload Artifacts](https://github.com/robvanoostenrijk/openconnect-server-static/actions/workflows/main.yml/badge.svg)](https://github.com/robvanoostenrijk/openconnect-server-static/actions/workflows/main.yml)

## Static ocserv (OpenConnect VPN Server) ##

This repository contains a Dockerfile to build a statically compiled [ocserv](https://ocserv.gitlab.io/www/).

Compilation is done using alpine and results in the following executable:

    ocserv 1.1.3

    Compiled with: PKCS#11, AnyConnect
    GnuTLS version: 3.7.2

A default Alpine based dynamic compiled version is included in `Dockerfile-alpine`.

The included script `generate-artifacts.sh` executes the docker build and places the generated artifacts into `./dist`.
