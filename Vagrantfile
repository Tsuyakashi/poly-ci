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
        "production-node" => { hostname: "production", ip: "192.168.56.11", memory: 2048, cpus: 2 }
    }

Vagrant.configure("2") do |config|
    config.vm.box = "bento/ubuntu-24.04"
    config.vm.boot_timeout = 300
    config.vm.synced_folder ".", "/vagrant", disabled: true    
    
    NODES.each do |name, cfg|
        config.vm.define name do |node|
            node.vm.hostname = cfg[:hostname]
            node.vm.network "private_network", ip: cfg[:ip]

            # Linux (Libvirt)
            node.vm.provider "libvirt" do |lv|
                lv.memory = cfg[:memory]
                lv.cpus   = cfg[:cpus]
                lv.storage_pool_name = "images"
            end
        
            # Windows (VirtualBox)
            node.vm.provider "virtualbox" do |vb|
                vb.memory = cfg[:memory]
                vb.cpus   = cfg[:cpus]
                vb.linked_clone = true 
            end


            if name == "runner-builder"
                node.vm.provision "configure_runner", type: "shell" do |s|
                    s.path = "scripts/runner.sh"
                    s.binary = true
                    s.env = { "REGISTRATION_TOKEN" => ENV['GITLAB_TOKEN'] }
                end
            end

            if name == "production-node"
                node.vm.provision "make_app_dir", type: "shell" do |s| 
                    s.inline = <<~SHELL
                        sudo mkdir -p \
                            /app/nginx \
                            /app/monitoring \
                            && sudo chown -R vagrant:vagrant /app
                    SHELL
                end

                node.vm.provision "file", source: "docker-compose.yml", destination: "/app/docker-compose.yml"
                node.vm.provision "file", source: "nginx/nginx.conf", destination: "/app/nginx/nginx.conf"
                node.vm.provision "file", source: "monitoring/filebeat.yml", destination: "/app/monitoring/filebeat.yml"
                node.vm.provision "file", source: "monitoring/logstash.conf", destination: "/app/monitoring/logstash.conf"
                node.vm.provision "file", source: "monitoring/logstash-template.json", destination: "/app/monitoring/logstash-template.json"
                node.vm.provision "file", source: "monitoring/kibana.yml", destination: "/app/monitoring/kibana.yml"


                node.vm.provision "configure_production", type: "shell" do |s|
                    s.path = "scripts/production.sh"
                    s.binary = true
                    s.env = { 
                        "WATCHTOWER_TOKEN"  => ENV['WATCHTOWER_TOKEN'],
                        "REGISTRY_USER"     => ENV['REGISTRY_USER'],
                        "REGISTRY_PASSWORD" => ENV['REGISTRY_PASSWORD'], 
                        "BASE_REGISTRY"     => ENV['BASE_REGISTRY']
                    }
                end
            end
        end
    end
end
