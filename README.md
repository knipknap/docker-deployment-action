# Docker Swarm Deployment Action

A GitHub Action that supports docker-compose and Docker Swarm deployments.

Originally forked from wshihadeh/docker-deployment-action, but largely rewritten
to improve Docker Swarm support (and drop docker-compose support) and fix bugs.

## Example

Below is a brief example on how the action can be used:

```yaml
- name: Deploy to Docker swarm
  uses: wshihadeh/docker-deployment-action@v1
  with:
    remote_docker_host: user@myswarm.com
    ssh_private_key: ${{ secrets.DOCKER_SSH_PRIVATE_KEY }}
    ssh_public_key: ${{ secrets.DOCKER_SSH_PUBLIC_KEY }}
    deploy_path: /root/my-deployment
    stack_file_name: docker-compose.yaml
    keep_files: 5
    args: my_applicaion
```

## Input Configurations

Below are all of the supported inputs. Some inputs are considered sensitive information and it should be stored as secrets.

### `args`

Arguments to pass to the deployment command (`docker stack deploy`).

### `remote_docker_host`

Specify Remote Docker host. The input value must be in the follwing format (user@host)

### `ssh_public_key`

Remote Docker SSH public key.

### `ssh_private_key`

SSH private key used to connect to the docker host

### `deploy_path`
The path where the stack files will be copied to. Default ~/docker-deployment.

### `stack_file_name`
Docker stack file used. Default is docker-compose.yaml

### `env_file_name`
Docker environment file used to substitute variables in the stack file. Default is .env

### `keep_files`
Number of the files to be kept on the server. Default is 3.

### `docker_prune`
A boolean input to trigger docker prune command.

### `pull_images_first`
Pull docker images using docker-compose before deploying.

## License

This project is licensed under the MIT license. See the [LICENSE](LICENSE) file for details.
