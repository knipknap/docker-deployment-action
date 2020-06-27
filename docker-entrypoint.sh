#!/bin/sh
set -eu

execute_ssh(){
  echo "Execute Over SSH: $@"
  ssh -q -t -i "$HOME/.ssh/id_rsa" \
      -o UserKnownHostsFile=/dev/null \
      -o StrictHostKeyChecking=no "$INPUT_REMOTE_DOCKER_HOST" "$@"
}

if [ -z "$INPUT_REMOTE_DOCKER_HOST" ]; then
    echo "Input remote_docker_host is required!"
    exit 1
fi

if [ -z "$INPUT_SSH_PUBLIC_KEY" ]; then
    echo "Input ssh_public_key is required!"
    exit 1
fi

if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
    echo "Input ssh_private_key is required!"
    exit 1
fi

if [ -z "$INPUT_ARGS" ]; then
  echo "Input input_args is required!"
  exit 1
fi

if [ -z "$INPUT_DEPLOY_PATH" ]; then
  INPUT_DEPLOY_PATH=~/docker-deployment
fi

if [ -z "$INPUT_STACK_FILE_NAME" ]; then
  INPUT_STACK_FILE_NAME=docker-compose.yaml
fi

if [ -z "$INPUT_ENV_FILE_NAME" ]; then
  INPUT_ENV_FILE_NAME=.env
fi

if [ -z "$INPUT_KEEP_FILES" ]; then
  INPUT_KEEP_FILES=4
else
  INPUT_KEEP_FILES=$((INPUT_KEEP_FILES+1))
fi

echo "Registering SSH keys..."
SSH_HOST=${INPUT_REMOTE_DOCKER_HOST#*@}

# register the private key with the agent.
mkdir -p "$HOME/.ssh"
printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > "$HOME/.ssh/id_rsa"
chmod 600 "$HOME/.ssh/id_rsa"
eval $(ssh-agent)
ssh-add "$HOME/.ssh/id_rsa"

echo "Add known hosts"
printf '%s %s\n' "$SSH_HOST" "$INPUT_SSH_PUBLIC_KEY" > /etc/ssh/ssh_known_hosts

if ! [ -z "$INPUT_DOCKER_PRUNE" ] && [ $INPUT_DOCKER_PRUNE = 'true' ] ; then
  yes | docker --log-level debug --host "ssh://$INPUT_REMOTE_DOCKER_HOST" system prune -a 2>&1
fi

# Copy the stack file, keeping a history in the stacks/ subdir.
execute_ssh "mkdir -p $INPUT_DEPLOY_PATH/stacks || true"
FILE_NAME="docker-stack-$(date +%Y%m%d%s).yaml"
scp -i "$HOME/.ssh/id_rsa" \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    $INPUT_STACK_FILE_NAME "$INPUT_REMOTE_DOCKER_HOST:$INPUT_DEPLOY_PATH/stacks/$FILE_NAME"
execute_ssh "ls -t $INPUT_DEPLOY_PATH/stacks/docker-stack-* 2>/dev/null | sed -e 1,${INPUT_KEEP_FILES}d | xargs rm --  2>/dev/null || true"

# Empty or create a build dir, and link the stack file in it.
# We also create all directories that are referenced by the stack file, as otherwise
# "docker-compose config" fails. Unfortunately there is not way to skip the check.
execute_ssh "rm -rf $INPUT_DEPLOY_PATH/build/; mkdir -p $INPUT_DEPLOY_PATH/build || true"
execute_ssh "ln -nfs $INPUT_DEPLOY_PATH/stacks/$FILE_NAME $INPUT_DEPLOY_PATH/build/$INPUT_STACK_FILE_NAME"
execute_ssh "cd $INPUT_DEPLOY_PATH/build; egrep '    (context:|build)' < ${INPUT_STACK_FILE_NAME} | sed -E 's/\s+\S+:\s*//' | xargs mkdir -p ."

# Copy the .env file to allow vor variable substitution in the stack file.
scp -i "$HOME/.ssh/id_rsa" \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    $INPUT_ENV_FILE_NAME "$INPUT_REMOTE_DOCKER_HOST:$INPUT_DEPLOY_PATH/"

# Copy the docker config (containing registry credentials), as it's needed for the deploy command to pull images from a private registry.
DOCKER_CONFIG=/github/workflow/config.json
if [ -f ${DOCKER_CONFIG} ]; then
  execute_ssh "mkdir -p ~/.docker || true"
  scp -i "$HOME/.ssh/id_rsa" \
      -o UserKnownHostsFile=/dev/null \
      -o StrictHostKeyChecking=no \
      ${DOCKER_CONFIG} "$INPUT_REMOTE_DOCKER_HOST:~/.docker/"
fi

if ! [ -z "$INPUT_PULL_IMAGES_FIRST" ] && [ $INPUT_PULL_IMAGES_FIRST = 'true' ] ; then
  execute_ssh "docker-compose -f $INPUT_DEPLOY_PATH/$INPUT_STACK_FILE_NAME pull"
fi

# Deploy
DEPLOYMENT_COMMAND="cd $INPUT_DEPLOY_PATH/build; docker-compose -f ${INPUT_STACK_FILE_NAME} config 2>/dev/null"
DEPLOYMENT_COMMAND="$DEPLOYMENT_COMMAND | docker stack deploy --with-registry-auth -c-"
execute_ssh "${DEPLOYMENT_COMMAND} $INPUT_ARGS" 2>&1
