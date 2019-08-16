# OneClick application
Simple application written in go

## Build
There are couple ways to build this application.
 - Build on your local
 - Build on CI/CD

### Build on your local
`docker build -t app:latest .`

### Build on CI/CD
This will be controlled by Jenkins server and triggered by commit push in Github.

## Test
There are few test cases *are in progress*
 1. Heathcheck page, `/healthcheck`, return 200 in any request
 2. Portal page, `/home`, return 401 in any illegal character that found in path.

## Run
### Run on local

`docker run --name app -p 3000:3000 app:latest` 

### Run on CI/CD

It should be managed by Jenkins pipeline with proper network, storage, and resources control.

`docker-compose apply`

# Infrastructure

Please refer to this [repo](https://github.com/lancekuo/terraform-docker-swarm), Terraform powered Docker Swarm cluster. 

Start from separated VPC, Subnet, Internet gateway or NAT gateway to Lambda backup, Docker Swarm, and private docker registry. Grafana,  prometheus, and ELK included. Rexray dynamic storage plugin ready.

# Appendix

There are couple additional files in this repo.

1. **Dockerfile**, build docker image from scratch and have a optimized final image. (1/8 of original image)
2. **Jenkinsfile**, demonstrate how to build/deploy and control flow in Jenkins
3. **docker-compose.yaml**, define resource requirement in docker swarm cluster