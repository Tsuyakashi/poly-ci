if File.exist?(".env")
    File.foreach(".env") do |line|
        next if line.strip.empty? || line.start_with?("#")
        key, value = line.strip.split('=', 2)
        ENV[key] = value.gsub(/\A['"]|['"]\z/, '')
    end
end


ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'

NODES = {
    "runner-node"     => { hostname: "runner",     ip: "192.168.56.10", memory: 1024, cpus: 1 },
    "production-node" => { hostname: "production", ip: "192.168.56.11", memory: 1024, cpus: 1 },
    "monitoring-node" => { hostname: "monitoring", ip: "192.168.56.12", memory: 2048, cpus: 2 },
}


Vagrant.configure("2") do |config|
    

    config.vm.box          = "bento/ubuntu-24.04"
    config.vm.boot_timeout = 300

    config.vm.synced_folder ".", "/vagrant", disabled: true    

    NODES.each do |name, cfg|
        config.vm.define name do |node|
            node.vm.hostname = cfg[:hostname]
            node.vm.network "private_network", ip: cfg[:ip]

            # Libvirt (Linux host)
            node.vm.provider "libvirt" do |lv|
                lv.memory            = cfg[:memory]
                lv.cpus              = cfg[:cpus]
                lv.storage_pool_name = "images"
            end
        
            # VirtualBox (Windows host)
            node.vm.provider "virtualbox" do |vb|
                vb.memory       = cfg[:memory]
                vb.cpus         = cfg[:cpus]
                vb.linked_clone = true
            end


            if name == "runner-node"
                node.vm.provision "configure_runner", type: "shell" do |s|
                    s.path   = "scripts/runner.sh"
                    s.binary = true
                    s.env    = { "REGISTRATION_TOKEN" => ENV['GITLAB_TOKEN'] }
                end
            end

            if name == "production-node"
                node.vm.provision "make_app_dir", type: "shell" do |s|
                        s.inline = <<~SHELL
                        sudo mkdir -p /app/nginx /app/configs/filebeat  \
                            && sudo chown -R vagrant:vagrant /app
                    SHELL
                end
        
                node.vm.provision "file", source: "docker-compose.yml",          destination: "/app/docker-compose.yml"
                node.vm.provision "file", source: "nginx/nginx.conf",            destination: "/app/nginx/nginx.conf"
                node.vm.provision "file", source: "configs/filebeat/config.yml", destination: "/app/configs/filebeat/config.yml"
        
                node.vm.provision "configure_production", type: "shell" do |s|
                    s.path   = "scripts/production.sh"
                    s.binary = true
                    s.env    = {
                        "WATCHTOWER_TOKEN"  => ENV['WATCHTOWER_TOKEN'],
                        "REGISTRY_USER"     => ENV['REGISTRY_USER'],
                        "REGISTRY_PASSWORD" => ENV['REGISTRY_PASSWORD'],
                        "BASE_REGISTRY"     => ENV['BASE_REGISTRY']
                    }
                end
            end

            if name == "monitoring-node"
                node.vm.provision "make_app_dir", type: "shell" do |s|
                    s.inline = <<~SHELL
                    sudo mkdir -p /app/configs/elasticsearch /app/configs/kibana /app/configs/logstash/pipelines /app/scripts \
                        && sudo chown -R vagrant:vagrant /app
                    SHELL
                end
                
                node.vm.provision "file", source: "docker-compose.monitoring.yml",                             destination: "/app/docker-compose.yml"
                node.vm.provision "file", source: "scripts/es-setup.sh",                                       destination: "/app/scripts/es-setup.sh"
                node.vm.provision "file", source: "configs/elasticsearch/config.yml",                          destination: "/app/configs/elasticsearch/config.yml"
                node.vm.provision "file", source: "configs/logstash/config.yml",                               destination: "/app/configs/logstash/config.yml"
                node.vm.provision "file", source: "configs/logstash/pipelines.yml",                            destination: "/app/configs/logstash/pipelines.yml"
                node.vm.provision "file", source: "configs/logstash/pipelines/service_stamped_json_logs.conf", destination: "/app/configs/logstash/pipelines/service_stamped_json_logs.conf"
                node.vm.provision "file", source: "configs/kibana/config.yml",                                 destination: "/app/configs/kibana/config.yml"
                node.vm.provision "file", source: "configs/kibana/dashboards.ndjson",                          destination: "/app/configs/kibana/dashboards.ndjson"

                node.vm.provision "configure_monitoring", type: "shell" do |s|
                    s.path   = "scripts/monitoring.sh"
                    s.binary = true
                    s.env    = {
                        "ELASTIC_PASSWORD"        => ENV['ELASTIC_PASSWORD'],
                        "KIBANA_SYSTEM_PASSWORD"  => ENV['KIBANA_SYSTEM_PASSWORD'],
                    }
                end
            end
        end
    end
end
