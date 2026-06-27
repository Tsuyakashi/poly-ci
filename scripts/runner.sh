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
mkdir -p /home/vagrant/actions-runner
curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    | tar xz -C /home/vagrant/actions-runner

sudo chown -R vagrant:vagrant /home/vagrant/actions-runner

sudo -u vagrant /home/vagrant/actions-runner/config.sh \
    --url "https://github.com/$GITHUB_REPO" \
    --token "$GITHUB_RUNNER_TOKEN" \
    --name "vagrant-linux" \
    --labels "linux,self-hosted" \
    --unattended \
    --replace

sudo /home/vagrant/actions-runner/svc.sh install vagrant
sudo /home/vagrant/actions-runner/svc.sh start


# Bitbucket runner работает как Docker контейнер
echo "Installing and starting bitbucket runner"
sudo docker container run -it -d \
    -v /tmp:/tmp \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
    -e ACCOUNT_UUID=$BB_ACCOUNT_UUID \
    -e REPOSITORY_UUID=$BB_REPOSITORY_UUID \
    -e RUNNER_UUID=$BB_RUNNER_UUID \
    -e RUNTIME_PREREQUISITES_ENABLED=true \
    -e OAUTH_CLIENT_ID=$BB_OAUTH_CLIENT_ID \
    -e OAUTH_CLIENT_SECRET=$BB_OAUTH_CLIENT_SECRET \
    -e WORKING_DIRECTORY=/tmp \
    --name bitbukcet-runner \
    docker-public.packages.atlassian.com/sox/atlassian/bitbucket-pipelines-runner

# Jenkins
echo "Installing Jenkins"
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update -qq
sudo apt-get install -y openjdk-17-jdk jenkins

sudo usermod -aG docker jenkins
sudo systemctl enable --now jenkins

# Ждём пока Jenkins поднимется
echo "Waiting for Jenkins to start..."
until curl -sf http://localhost:8080/login > /dev/null; do sleep 3; done

# Отключаем wizard setup
sudo bash -c 'echo 2 > /var/lib/jenkins/jenkins.install.UpgradeWizard.state'
sudo mkdir -p /var/lib/jenkins/init.groovy.d

# Устанавливаем пароль админа
sudo tee /var/lib/jenkins/init.groovy.d/01-admin.groovy > /dev/null <<GROOVY
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "${JENKINS_ADMIN_PASSWORD}")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)
instance.save()
GROOVY

# Создаём credentials
sudo tee /var/lib/jenkins/init.groovy.d/02-credentials.groovy > /dev/null <<GROOVY
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import hudson.util.Secret

def store = Jenkins.getInstance()
    .getExtensionList("com.cloudbees.plugins.credentials.SystemCredentialsProvider")[0]
    .getStore()
def domain = Domain.global()

store.addCredentials(domain, new UsernamePasswordCredentialsImpl(
    CredentialsScope.GLOBAL, "gitlab-registry", "GitLab Registry",
    "${REGISTRY_USER}", "${REGISTRY_PASSWORD}"
))

store.addCredentials(domain, new StringCredentialsImpl(
    CredentialsScope.GLOBAL, "watchtower-token", "Watchtower Token",
    Secret.fromString("${WATCHTOWER_TOKEN}")
))
GROOVY

# Создаём pipeline job
sudo tee /var/lib/jenkins/init.groovy.d/03-job.groovy > /dev/null <<GROOVY
import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.*
import org.jenkinsci.plugins.workflow.cps.*
import hudson.plugins.git.*
import com.cloudbees.plugins.credentials.*

def jenkins = Jenkins.getInstance()
def jobName = "poly-ci"

if (jenkins.getItem(jobName) == null) {
    def job = jenkins.createProject(WorkflowJob.class, jobName)
    job.setDefinition(new CpsScmFlowDefinition(
        new GitSCM("https://github.com/${GITHUB_REPO}.git"),
        "Jenkinsfile"
    ))
    job.save()
}
jenkins.save()
GROOVY

sudo chown -R jenkins:jenkins /var/lib/jenkins/init.groovy.d/

# Устанавливаем плагины через CLI
sudo systemctl restart jenkins
until curl -sf http://localhost:8080/login > /dev/null; do sleep 3; done

sudo curl -fsSL http://localhost:8080/jnlpJars/jenkins-cli.jar -o /tmp/jenkins-cli.jar
sleep 10  # ждём полной инициализации после restart

java -jar /tmp/jenkins-cli.jar \
    -s http://localhost:8080 \
    -auth "admin:${JENKINS_ADMIN_PASSWORD}" \
    install-plugin \
        workflow-aggregator git credentials-binding \
        docker-workflow github \
    -restart

echo "All done"
