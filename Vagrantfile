if File.exist?(".env")
    File.foreach(".env") do |line|
        next if line.strip.empty? || line.start_with?("#")
        key, value = line.strip.split('=', 2)
        ENV[key] = value.gsub(/\A['"]|['"]\z/, '') 
    end
end
  

ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'

NODES = 
    {
        "runner-builder" => { hostname: "runner", ip: "192.168.56.10", memory: 1024, cpus: 1 },
        "production-node" => { hostname: "production", ip: "192.168.56.11", memory: 1024, cpus: 1 }
    }

Vagrant.configure("2") do |config|
    config.vagrant.plugins = ["vagrant-libvirt"]
    config.vm.box = "bento/ubuntu-24.04"
    config.vm.boot_timeout = 300
    
    config.vm.synced_folder ".", "/vagrant", disabled: true
    
    config.vm.provider "libvirt" do |lv|
        lv.storage_pool_name = "images"
    end
    
    
    NODES.each do |name, cfg|
        config.vm.define name do |node|
            node.vm.hostname = cfg[:hostname]
            node.vm.network "private_network", ip: cfg[:ip]

            node.vm.provider "libvirt" do |lv|
                lv.memory = cfg[:memory]
                lv.cpus   = cfg[:cpus]
            end


            if name == "runner-builder"
                node.vm.provision "configure_runner", type: "shell" do |s|
                    s.env = { "REGISTRATION_TOKEN" => ENV['GITLAB_TOKEN'] }
                    s.inline = <<-SHELL
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
                        
                        SHELL
                end
            end

            if name == "production-node"
                node.vm.provision "configure_production", type: "shell" do |s|
                    s.env = { 
                        "WATCHTOWER_TOKEN"  => ENV['WATCHTOWER_TOKEN'],
                        "REGISTRY_USER"     => ENV['REGISTRY_USER'],
                        "REGISTRY_PASSWORD" => ENV['REGISTRY_PASSWORD'], 
                        "APP_IMAGE"         => ENV['APP_IMAGE']
                    }
                    s.inline = <<-SHELL
                        # Install Docker    
                        sudo DEBIAN_FRONTEND=noninteractive apt-get update && \
                            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io

                        # Auth system docker with private gitlab repo
                        echo "$REGISTRY_PASSWORD" | sudo docker login registry.gitlab.com -u "$REGISTRY_USER" --password-stdin

                        # Pull image from registry
                        sudo docker pull "$APP_IMAGE" || echo "Warning: Image is not ready in registry"

                        #  Run container if image is ready
                        if sudo docker image inspect "$APP_IMAGE" >/dev/null 2>&1; then
                            sudo docker rm -f bsuir-app 2>/dev/null || true
                            sudo docker run -d \
                            --name bsuir-app \
                            -p 80:80 \
                            --restart unless-stopped \
                            "$APP_IMAGE"
                        fi

                        # Remove old watchtower container if exists to avoid conflicts
                        sudo docker rm -f watchtower 2>/dev/null || true

                        # Configure watchtower
                        sudo docker run -d \
                            --name watchtower \
                            -v /var/run/docker.sock:/var/run/docker.sock \
                            -p 8080:8080 \
                            --restart unless-stopped \
                            -e REPO_USER="$REGISTRY_USER" \
                            -e REPO_PASS="$REGISTRY_PASSWORD" \
                            -e DOCKER_API_VERSION="1.44" \
                            containrrr/watchtower \
                            --interval 300 \
                            --http-api-update \
                            --http-api-token "$WATCHTOWER_TOKEN" \
                            --cleanup

                        sudo mkdir -p /app
                        sudo chmod 777 /app
                    SHELL
                end
            end
        end
    end
end