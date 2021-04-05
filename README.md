## PHP (Laravel) + Docker Hello World, for Showing Good Defaults for Using A PHP Stack in Docker

> This tries to be a "good defaults" example of using PHP, Nginx, PHP-FPM, Laravel, and Composer in Docker for local development and shipping to production with all the bells, whistles, and best practices. Issues/PR welcome.

**NOTE:** This is not a full PHP sample project. It's a collection of the Docker and Nginx related things you'll need to have this sort of setup fully in Docker. I'm not a PHP/Laravel developer, but rather an ops guy working with many smart PHP dev's. I continue to refine this repo as I work with teams to dev with, test on, and deploy production containers on PHP.

Also Note [I have courses on Docker, Swarm, and upcoming Docker for Node.js here](https://www.bretfisher.com/docker).

### Official Laravel Docker Environment

As of version 8 of Laravel there is an offically supported Docker development environment called 'Sail'.  If you are specifically doing Laravel development you may want to check it out at [the Laravel website](https://laravel.com/docs/sail).

### Contribuitions

This project was made possible in part with support and development from [PrinterLogic](https://www.printerlogic.com/).

### Local Development Features

 - **Dev as close to prod as you can**. docker-compose builds a local development image that is just like production image except for the below dev-only features needed in image. Goal is to have dev env be as close to test and prod as possible while still giving all the nice tools to make you a happy dev.
 - **Prevent needing node/npm on host**. Installs `node_modules` outside app root in container so local development won't run into a problem of bind-mounting over it with local source code. This means it will run `npm install` once on container build and you don't need to run npm on host or on each docker run. It will re-run on build if you change `package.json`.
 - **One line startup**. Uses `docker-compose up` for single-line build and run of local development server.
 - **Edit locally while code runs in container**. docker-compose uses proper bind-mounts of host source code into container so you can edit locally while running code in Linux container.
 - **Enable debug from host to container**. opens the legacy debug port 5858 and new inspect port 9229 for using host-based debugging like chrome tools or VS Code. Nodemon enables `--inspect` by default in docker-compose, but you can change to `--debug` for < 6.3 debugging.
 - **Quick re-builds**. `COPY` in `package.json` and run `npm install && npm cache clean` **before** `COPY` in your source code. This saves big on build time and keep container lean. Same for Composer and Bower.


### Production-minded Features

 - **Use Docker build-in healthchecks**. uses Dockerfile `HEALTHCHECK` with php-fpm `/ping` route to help Docker know if your container is running properly.
 - **Nginx + PHP-FPM in one container**. Supervisor is used to combine the two services, Nginx and PHP-FPM in a single container. Those two services have to work together to give you a webserver and PHP processor. Unlike Apache + mod\_php, which runs under the Apache process and only needs to start one process on container startup, the combo of Nginx + PHP-FPM have to be started separately. Docker is designed to run a single process with CMD in the Dockerfile, so the simple Supervisor program is used to manage them with a simple config file. Having them both in one container makes the app easier to manage in my real-world experience. [Docker has a Docs page on various ways to start multi-service containers](https://docs.docker.com/engine/admin/multi-service_container/), showing a Supervisor example. So far, the Nginx + PHP-FPM combo is the *only* scenario that I recommend using multi-service containers for. It's a rather unique problem that doesn't always fit well in the model of "one container, one service". You *could* use two separate containers, one with `nginx` and one with `php:fpm` but I've tried that in production, and there are lots of downsides. A copy of the PHP code has to be in each container, they have to communicate over TCP which is much slower than Linux sockets used in a single container, and since you usually have a 1-to-1 relationship between them, the argument of individual service control is rather moot.


### Assumptions

 - You have Docker and Docker-Compose installed (Docker for Mac, Docker for Windows, get.docker.com and manual Compose installed for Linux).
 - You want to use Docker for local development (i.e. never need to install php or npm on host) and have dev and prod Docker images be as close as possible.
 - You don't want to lose fidelity in your dev workflow. You want a easy environment setup, using local editors, debug/inspect, local code repo, while web server runs in a container.
 - You use `docker-compose` for local development only (docker-compose was never intended to be a production deployment tool anyway).
 - The `docker-compose.yml` is not meant for `docker stack deploy` in Docker Swarm, it's meant for happy local development.

 
### Getting Started

If this was your app, to start local development you would:

 - Running `docker-compose up` is all you need. It will:
 - Build custom local image enabled for development.
 - Start container from that image with ports 80, 443, 9000, and 9001 open (on localhost or docker-machine).
 - Mount the pwd to the app dir in container.
 - If you need other services like databases, just add to compose file and they'll be added to the custom Docker network for this app on `up`.
 - If you need to add packages to Composer, npm, bower, etc. then stop docker-compose and run `docker-compose up --build` to ensure image is updated.
 - Be sure to use `docker-compose down` to cleanup after your done dev'ing.



MIT License, 

Copyright (c) Bret Fisher

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
