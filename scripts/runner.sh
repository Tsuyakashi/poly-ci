#!/bin/bash
(set -o posix; [ -f /usr/bin/dos2unix ] || (sudo apt-get update && sudo apt-get install -y dos2unix)) && dos2unix "$0"

# Install Docker
sudo DEBIAN_FRONTEND=noninteractive apt-get update && \
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io

# Download the binary for your system
sudo curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64
# Give it permission to execute
sudo chmod +x /usr/local/bin/gitlab-runner
# Create a GitLab Runner user
sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash
# Install and run as a service
sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
sudo gitlab-runner start

# Fix Ubuntu skeleton files for non-interactive shell sessions
sudo mv /home/gitlab-runner/.bash_logout /home/gitlab-runner/.bash_logout.bak 2>/dev/null || true
sudo mv /home/gitlab-runner/.profile /home/gitlab-runner/.profile.bak 2>/dev/null || true
sudo mv /home/gitlab-runner/.bashrc /home/gitlab-runner/.bashrc.bak 2>/dev/null || true
sudo touch /home/gitlab-runner/.profile
sudo chown gitlab-runner:gitlab-runner /home/gitlab-runner/.profile

# Non interative runner registation
sudo gitlab-runner register \
    --non-interactive \
    --url "https://gitlab.com/" \
    --token "$REGISTRATION_TOKEN" \
    --executor "docker" \
    --docker-image "docker:24.0.9" \
    --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
    --description "vagrant-linux-docker-builder"
