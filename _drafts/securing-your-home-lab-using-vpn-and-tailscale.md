---
title: Securing your home lab using VPN and Tailscale
header:
	image: '/images/securing-your-home-lab-using-vpn-and-tailscale/header.png'
category: Docker
tags:
    - Home-Lab
    - VPN
    - Tailscale
    - Docker
---

## Introduction

Over the last several years my homelab has grown from a single Raspberry Pi 4 to several in a Docker Swarm cluster. As the number of apps being hosted on that cluster has also grown I've wanted to start to access these remotely without having to open up ports on my router. The requirements I had for the VPN were

- Can be deployed as a Docker Container
- Docker image must support ARM for the RPIs
- An administration UI to manage multiple devices connecting to the VPN network
- Can be deployed using [Docker-Compose](https://docs.docker.com/compose/compose-file/) to document and automate the process

## Initial attempts

### OpenVPN AS (Access Server)

When I initially started looking for VPN servers, OpenVPN was still very popular and I'd used it previously on bare-metal servers. There was even a popular [ARM based image on Docker Hub](https://hub.docker.com/r/giggio/openvpn-arm) with decent documentation to get started. However, there were a few issues:

- ARM support was not widely available and so there was little to no security patches
- The server required an **init** making it difficult deploy using Docker-Compose
- At the time there were no ARM based web UIs

## Wireguard

**[Wireguard](https://www.wireguard.com)** has been around for a number of years but is the latest VPN protocol which offers improved speeds over OpenVPN as well as better security. One of the features of Wireguard is that it runs in the **kernel-space** which is part of the reason for the performance improvements. However, with Wireguard running in the kernel, this goes against **[how Docker works](https://stackoverflow.com/questions/16047306/how-is-docker-different-from-a-virtual-machine)** in that the containers share the kernel with the host meaning to run Wireguard properly requires kernel modules to be deploy to every host the container could run on.

A couple of honourable mentions of Docker images:

- [linuxserver.io Wireguard image](https://hub.docker.com/r/linuxserver/wireguard) - A kernel based Wireguard server/client which supports ARM and receives regular base image updates
- [Wireguard UI](https://hub.docker.com/r/ngoduykhanh/wireguard-ui) - A simple Web UI for Wireguard with ARM support for adding clients complete with QR codes for configuring clients