#!/bin/bash
(set -o posix; [ -f /usr/bin/dos2unix ] || (sudo apt-get update &>/dev/null && sudo apt-get install -y dos2unix &>/dev/null)) && dos2unix "$0"

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

if [ -n "$GITHUB_PAT" ]; then
    API_RESPONSE=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_PAT" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_REPO/actions/runners/registration-token")
    GITHUB_RUNNER_TOKEN=$(echo "$API_RESPONSE" \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])" 2>/dev/null)
fi

RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
mkdir -p /home/vagrant/actions-runner
curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    | tar xz -C /home/vagrant/actions-runner
sudo chown -R vagrant:vagrant /home/vagrant/actions-runner

if [ -n "$GITHUB_RUNNER_TOKEN" ]; then
    if sudo -u vagrant /home/vagrant/actions-runner/config.sh \
        --url "https://github.com/$GITHUB_REPO" \
        --token "$GITHUB_RUNNER_TOKEN" \
        --name "vagrant-linux" \
        --labels "linux,self-hosted" \
        --unattended \
        --replace; then
        sudo bash -c 'cd /home/vagrant/actions-runner && ./svc.sh install vagrant'
        sudo bash -c 'cd /home/vagrant/actions-runner && ./svc.sh start'
        echo "GitHub Actions runner started"
    else
        echo "WARNING: config.sh failed" >&2
    fi
else
    echo "WARNING: failed to obtain GitHub runner token" >&2
fi

# Bitbucket runner работает как Docker контейнер
echo "Installing and starting bitbucket runner"

# Если продолжит падать по OOM увеличить в Vagrantfile
sudo docker container run -d \
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
    -e JAVA_OPTS="-Xmx256m -Xms128m" \
    --memory=512m \
    --name bitbucket-runner \
    docker-public.packages.atlassian.com/sox/atlassian/bitbucket-pipelines-runner

# Self-hosted Docker Registry
echo "Starting self-hosted Docker Registry"
sudo docker run -d \
    --name registry \
    --restart always \
    -p 5000:5000 \
    -v /var/lib/registry:/var/lib/registry \
    registry:2

sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "insecure-registries": ["192.168.56.10:5000"]
}
EOF
sudo systemctl restart docker

# Jenkins
echo "Installing Jenkins"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-21-jdk &>/dev/null

sudo useradd -m -d /var/lib/jenkins -s /bin/bash jenkins 2>/dev/null || true
sudo usermod -aG docker jenkins

sudo wget -qO /opt/jenkins.war https://get.jenkins.io/war-stable/latest/jenkins.war

sudo tee /etc/systemd/system/jenkins.service > /dev/null <<EOF
[Unit]
Description=Jenkins
After=network.target

[Service]
User=jenkins
ExecStart=/usr/bin/java \
  -Dhudson.security.csrf.GlobalCrumbIssuerConfiguration.DISABLE_CSRF_PROTECTION=true \
  -jar /opt/jenkins.war --httpPort=8080
Environment="JENKINS_HOME=/var/lib/jenkins"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

sudo mkdir -p /var/lib/jenkins/init.groovy.d
sudo bash -c 'echo 2 > /var/lib/jenkins/jenkins.install.UpgradeWizard.state'

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

sudo mkdir -p /var/lib/jenkins
sudo tee /var/lib/jenkins/jenkins.model.JenkinsLocationConfiguration.xml > /dev/null <<XML
<?xml version='1.1' encoding='UTF-8'?>
<jenkins.model.JenkinsLocationConfiguration>
  <adminAddress>address not configured yet &lt;nobody@nowhere&gt;</adminAddress>
  <jenkinsUrl>http://192.168.56.10:8080/</jenkinsUrl>
</jenkins.model.JenkinsLocationConfiguration>
XML

sudo chown -R jenkins:jenkins /var/lib/jenkins/

sudo systemctl enable --now jenkins

echo "Waiting for Jenkins to start..."
until curl -sf http://localhost:8080/login > /dev/null; do sleep 3; done
sleep 30

# Хелпер: выполнить Groovy через Script Console (через файл — без проблем с экранированием)
run_groovy() {
    local script_file
    script_file=$(mktemp /tmp/jenkins-groovy-XXXXXX.groovy)
    cat > "$script_file" <<'SCRIPT_EOF'
SCRIPT_EOF
    printf '%s' "$1" > "$script_file"
    curl -sf \
        -u "admin:${JENKINS_ADMIN_PASSWORD}" \
        "http://localhost:8080/scriptText" \
        --data-urlencode "script@${script_file}"
    rm -f "$script_file"
}

# Установка плагинов через Script Console
echo "Installing plugins..."
run_groovy '
import jenkins.model.*
def pm = Jenkins.getInstance().getPluginManager()
def uc = Jenkins.getInstance().getUpdateCenter()
uc.updateAllSites()
["workflow-aggregator","git","credentials-binding","docker-workflow","github"].each { name ->
    if (!pm.getPlugin(name)) {
        def plugin = uc.getPlugin(name)
        if (plugin) plugin.deploy(true)
    }
}
'

echo "Waiting for plugins to install..."
sleep 60

run_groovy 'Jenkins.getInstance().safeRestart()'

echo "Waiting for Jenkins to restart after plugin install..."
sleep 20
until curl -sf http://localhost:8080/login > /dev/null; do sleep 3; done
sleep 15

# Credentials + Job через Script Console
GROOVY_SCRIPT=$(cat <<GROOVY
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.util.Secret
import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.*
import org.jenkinsci.plugins.workflow.cps.*
import hudson.plugins.git.*

def jenkins = Jenkins.getInstance()
def store = jenkins
    .getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0]
    .getStore()

if (!store.getCredentials(Domain.global()).find { it.id == 'watchtower-token' }) {
    store.addCredentials(Domain.global(), new StringCredentialsImpl(
        CredentialsScope.GLOBAL, 'watchtower-token', 'Watchtower Token',
        Secret.fromString('${WATCHTOWER_TOKEN}')
    ))
}

def jobName = 'poly-ci'
if (jenkins.getItem(jobName) == null) {
    def job = jenkins.createProject(WorkflowJob.class, jobName)
    job.setDefinition(new CpsScmFlowDefinition(
        new GitSCM('https://github.com/${GITHUB_REPO}.git'),
        'Jenkinsfile'
    ))
    job.save()
}
jenkins.save()
GROOVY
)

GROOVY_FILE=$(mktemp /tmp/jenkins-groovy-XXXXXX.groovy)
printf '%s' "$GROOVY_SCRIPT" > "$GROOVY_FILE"
curl -sf \
    -u "admin:${JENKINS_ADMIN_PASSWORD}" \
    "http://localhost:8080/scriptText" \
    --data-urlencode "script@${GROOVY_FILE}"
rm -f "$GROOVY_FILE"

echo "All done"
