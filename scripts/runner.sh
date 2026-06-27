#!/bin/bash
(set -o posix; [ -f /usr/bin/dos2unix ] || (sudo apt-get update && sudo apt-get install -y dos2unix)) && dos2unix "$0"

# Install Docker
echo "Installing docker"
if ! command -v docker &> /dev/null; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get update &>/dev/null \
        && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io &>/dev/null
fi

sudo usermod -aG docker vagrant

echo "Installing and starting gitlab runner"
# Download the binary for your system
sudo curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64 &>/dev/null
# Give it permission to execute
sudo chmod +x /usr/local/bin/gitlab-runner  &>/dev/null
# Create a GitLab Runner user
sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash 2>/dev/null || true
# Install and run as a service
sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner || true
sudo gitlab-runner start

# Fix Ubuntu skeleton files for non-interactive shell sessions
sudo mv /home/gitlab-runner/.bash_logout /home/gitlab-runner/.bash_logout.bak 2>/dev/null || true
sudo mv /home/gitlab-runner/.profile /home/gitlab-runner/.profile.bak 2>/dev/null || true
sudo mv /home/gitlab-runner/.bashrc /home/gitlab-runner/.bashrc.bak 2>/dev/null || true
sudo touch /home/gitlab-runner/.profile
sudo chown gitlab-runner:gitlab-runner /home/gitlab-runner/.profile

echo "Non interactive runner registration"
# Non interative runner registation
sudo gitlab-runner register \
    --non-interactive \
    --url "https://gitlab.com/" \
    --token "$REGISTRATION_TOKEN" \
    --executor "docker" \
    --docker-image "docker:24.0.9" \
    --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
    --description "vagrant-linux-docker-builder"


# GitHub runner
echo "Installing and starting github actions runner"
RUNNER_VERSION="2.317.0"
mkdir -p /home/vagrant/actions-runner && cd /home/vagrant/actions-runner

curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    | tar xz

sudo chown -R vagrant:vagrant /home/vagrant/actions-runner

sudo -u vagrant ./config.sh \
    --url "https://github.com/$GITHUB_REPO" \
    --token "$GITHUB_RUNNER_TOKEN" \
    --name "vagrant-linux" \
    --labels "linux,self-hosted" \
    --unattended \
    --replace

sudo ./svc.sh install vagrant
sudo ./svc.sh start


# Bitbucket runner работает как Docker контейнер
echo "Installing and starting bitbucket runner"
docker run -it -d \
    -v /tmp:/tmp \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --name bitbucket-runner \
    --restart unless-stopped \
    -e ACCOUNT_UUID="$BB_ACCOUNT_UUID" \
    -e RUNNER_UUID="$BB_RUNNER_UUID" \
    -e OAUTH_CLIENT_ID="$BB_OAUTH_CLIENT_ID" \
    -e OAUTH_CLIENT_SECRET="$BB_OAUTH_CLIENT_SECRET" \
    -e WORKING_DIRECTORY=/tmp \
    docker-public.packages.atlassian.com/sox/atlassian/bitbucket-pipelines-runner:1
    
echo "All done"
