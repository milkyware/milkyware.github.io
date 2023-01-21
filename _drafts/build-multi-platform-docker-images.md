---
title: Build Multi-Platform Docker Images
header:
  image: '/images/build-multi-platform-docker-image/header.png'
category: DevOps
tags:
  - Docker
  - Docker Buildx
  - GitHib Actions
---

## Building multi-platform Docker images

Over the last couple of years I've been using [Docker](https://docs.docker.com/) more for running my home-lab to learn about containerisation by both deploying community images as well as packaging my own apps as images. I've also used this as an opportunity to get more familiar with [GitHub Actions](https://github.com/features/actions) as the [marketplace](https://github.com/marketplace) has been growing incredibly quickly.

In this post, I'm going to detail a collection of actions I've used to build and publish multi-platform images to multiple container registries.

## GitHub Action

### Complete GitHub Workflow

Below is the complete workflow I've put together and after we'll step through the main aspects of it.

<!-- {% raw %} -->
``` yaml
name: Docker CI

on:
  release:
    types:
      - published
  
  workflow_dispatch:

env:
  IMAGE_NAME: "imagename"
  DOCKERHUB_REGISTRY: "docker.io"
  GITHUB_REGISTRY: "ghcr.io"
  QUAY_REGISTRY: "quay.io"

jobs:
  build:
    name: Build image and push
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v2
        
      - name: Repository Owner Lower
        id: repository_owner_lower
        uses: ASzc/change-string-case-action@v2
        with:
          string: "${{github.repository_owner}}"
      
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v1
      
      - name: Install Buildx
        id: docker-buildx
        uses: docker/setup-buildx-action@v1.0.2
        with: 
          version: latest

      - name: Docker Metadata
        id: docker-metadata
        uses: docker/metadata-action@v4.0.1
        with:
          flavor: |
            latest=auto
          images: |
            ${{env.DOCKERHUB_REGISTRY}}/${{github.repository_owner}}/${{env.IMAGE_NAME}}
            ${{env.GITHUB_REGISTRY}}/${{github.repository_owner}}/${{env.IMAGE_NAME}}
            ${{env.QUAY_REGISTRY}}/${{github.repository_owner}}/${{env.IMAGE_NAME}}
          tags: |
            type=ref,event=tag
            type=sha
            type=semver,pattern={{major}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{version}}
      
      - name: Docker Hub login
        id: dockerhub-login
        uses: docker/login-action@v1.4.1
        with: 
          registry: "${{env.DOCKERHUB_REGISTRY}}"
          username: "${{secrets.DOCKERHUB_USERNAME}}"
          password: "${{secrets.DOCKERHUB_PASSWORD}}"
          
      - name: GHCR login
        id: github-login
        uses: docker/login-action@v1.4.1
        with: 
          registry: "${{env.GITHUB_REGISTRY}}"
          username: "${{github.repository_owner}}"
          password: "${{github.token}}"
          
      - name: Quay login
        id: quay-login
        uses: docker/login-action@v1.4.1
        with: 
          registry: "${{env.QUAY_REGISTRY}}"
          username: "${{secrets.QUAY_USERNAME}}"
          password: "${{secrets.QUAY_PASSWORD}}"
      
      - name: Docker build and push
        id: docker-build-push
        uses: docker/build-push-action@v2.3.0
        with:
          builder: ${{steps.docker-buildx.outputs.name}}
          context: .
          platforms: linux/arm64,linux/amd64
          push: true
          labels: ${{steps.docker-metadata.outputs.labels}}
          tags: ${{steps.docker-metadata.outputs.tags}}
          
      - name: Docker Hub Description
        id: docker-description
        uses: peter-evans/dockerhub-description@v3
        with:
          username: ${{secrets.DOCKERHUB_USERNAME}}
          password: ${{secrets.DOCKERHUB_PASSWORD}}
          repository: ${{secrets.DOCKERHUB_USERNAME}}/${{env.IMAGE_NAME}}
          readme-filepath: ./README.md
```
<!-- {% endraw %} -->

### Setting up the flow

The main setup needed is installing and enabling [Docker Buildx and QEMU](https://github.com/marketplace/actions/docker-setup-buildx) to emulate the various platform environments.

``` yaml
- name: Set up QEMU
  uses: docker/setup-qemu-action@v1

- name: Install Buildx
  id: docker-buildx
  uses: docker/setup-buildx-action@v1.0.2
  with: 
    version: latest
```

### Building the image tags

The next setup is an action I recently discovered called [Docker Metadata](https://github.com/marketplace/actions/docker-metadata-action). For this you can pass in a number of base images (e.g. docker.io/username/image) and configure a series of tags to apply to each of those images. This ensures consistency in tagging across multiple container registries. This action also supports extracting reading metadata when triggered by releases. In the example, tags are created for **major**, **major.minor** and **version** to allow users to pick a level of their containers auto-updating.

<!-- {% raw %} -->
``` yaml
- name: Docker Metadata
  id: docker-metadata
  uses: docker/metadata-action@v4.0.1
  with:
    flavor: |
      latest=auto
    images: |
      ${{env.DOCKERHUB_REGISTRY}}/${{github.repository_owner}}/${{env.IMAGE_NAME}}
      ${{env.GITHUB_REGISTRY}}/${{github.repository_owner}}/${{env.IMAGE_NAME}}
      ${{env.QUAY_REGISTRY}}/${{github.repository_owner}}/${{env.IMAGE_NAME}}
    tags: |
      type=ref,event=tag
      type=sha
      type=semver,pattern={{major}}
      type=semver,pattern={{major}}.{{minor}}
      type=semver,pattern={{version}}
      type=raw,value=ci
```
<!-- {% endraw %} -->

### Container registry login

Next is logging into each of the registries and is handled quite easily by providing the credentials from [GitHub Action secrets](https://docs.github.com/en/rest/actions/secrets). This needs to be done **per registry**

<!-- {% raw %} -->
``` yaml
- name: Docker Hub login
  id: dockerhub-login
  uses: docker/login-action@v1.4.1
  with: 
    registry: "${{env.DOCKERHUB_REGISTRY}}"
    username: "${{secrets.DOCKERHUB_USERNAME}}"
    password: "${{secrets.DOCKERHUB_PASSWORD}}"
```
<!-- {% endraw %} -->

### Build and pushing the image

The step brings all the previous steps together. For this we pass in the Docker build that was setup up in [setting up the flow](#setting-up-the-flow) as well as the **labels** and **tags** from [building the image tags](#building-the-image-tags).

<!-- {% raw %} -->
``` yaml
- name: Docker build and push
  id: docker-build-push
  uses: docker/build-push-action@v2.3.0
  with:
    builder: ${{steps.docker-buildx.outputs.name}}
    context: .
    platforms: linux/arm64,linux/amd64
    push: true
    labels: ${{steps.docker-metadata.outputs.labels}}
    tags: ${{steps.docker-metadata.outputs.tags}}
```
<!-- {% endraw %} -->

Two key properties are **platforms** and **push**. By default Docker will only build an image for the architecture of the workflow runner i.e. if the runner is x64, only x64 will be built. Also, the resulting images are not pushed by default. This may be intentional for running CI builds or running tests but will be required for deploying the image to container hosts. **IMPORTANT** Do keep in mind that the different platforms need to be supported by the:

- The base image(s) in the Dockerfile
- The packages and tools (if any) used in your code
- Your code

Once the image is published to the container registry, a particular tag will look similar to below. Below are screenshots from **Docker Hub** and **Quay**.

![image1](/images/build-multi-platform-docker-image/image1.png)

![image2](/images/build-multi-platform-docker-image/image2.png)

Above we can see the supported platforms of:

- linux/amd64
- linux/arm/v7
- linux/arm64

What this allows is for a single tag, such as *username/image:v1.6.1*, to be deployed on different platform architectures and then Docker will automatically resolve and pull the correct image.

### Bonus: Publishing the README

Most code repos contain Markdown documentation for getting started with the code as well as deploying it. Putting this documentation as close as possible to the published package really helps users and devs get started. Enter the final step the **[peter-evans/dockerhub-description](https://github.com/marketplace/actions/docker-hub-description)** GitHub Action which can take a Markdown file and publishes it to Docker Hub.

<!-- {% raw %} -->
``` yaml
- name: Docker Hub Description
  id: docker-description
  uses: peter-evans/dockerhub-description@v3
  with:
    username: ${{secrets.DOCKERHUB_USERNAME}}
    password: ${{secrets.DOCKERHUB_PASSWORD}}
    repository: ${{secrets.DOCKERHUB_USERNAME}}/${{env.IMAGE_NAME}}
    readme-filepath: ./README.md
```
<!-- {% endraw %} -->

Although in the above example I've used the README.md file, a seperate file could be provided which is more tailored to configuring and running the Docker image leaving the code documentation in the README.

## Summary

In this post we've stepped through how to automate publishing Docker images that are available to a wide audience, both those preferring different container registries as well as hosting the containers on different architectures. I've tried to keep the  GitHub workflow generic and concise so that it can be reused in other repos and only require a few parameters/variables to be updated. Hope this is of use and thanks for reading.
