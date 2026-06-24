    if File.exist?(".env")
        File.foreach(".env") do |line|
            next if line.strip.empty? || line.start_with?("#")
            key, value = line.strip.split('=', 2)
            ENV[key] = value.gsub(/\A['"]|['"]\z/, '')
        end
    end


    ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'

    # ─────────────────────────────────────────────────────────────────────────────
    # Platform selector
    #   PLATFORM=linux   (default) — bento/ubuntu-24.04, Libvirt/VirtualBox
    #   PLATFORM=windows           — gusztavvargadr/windows-server, Libvirt/VirtualBox
    #
    # Usage:
    #   vagrant up                          # Linux nodes
    #   PLATFORM=windows vagrant up         # Windows nodes
    # ─────────────────────────────────────────────────────────────────────────────
    PLATFORM = ENV.fetch('PLATFORM', 'linux').downcase
    unless %w[linux windows].include?(PLATFORM)
        abort "Unknown PLATFORM='#{PLATFORM}'. Use 'linux' or 'windows'."
    end

    puts "==> Platform: #{PLATFORM.upcase}"


    LINUX_NODES = {
        "runner-builder"  => { hostname: "runner",     ip: "192.168.56.10", memory: 1024, cpus: 1 },
        "production-node" => { hostname: "production", ip: "192.168.56.11", memory: 3072, cpus: 3 }
    }.freeze
    
    # Windows Server 2022 needs more RAM:
    #   runner: MCR daemon + gitlab-runner service
    #   prod:   MCR daemon + Hyper-V Linux VM for LCOW + nginx/app containers
    WINDOWS_NODES = {
        "runner-builder-win"  => { hostname: "runner-win",     ip: "192.168.56.20", memory: 2048, cpus: 2 },
        "production-node-win" => { hostname: "production-win", ip: "192.168.56.21", memory: 4096, cpus: 4 }
    }.freeze
    
    NODES = PLATFORM == 'windows' ? WINDOWS_NODES : LINUX_NODES


    Vagrant.configure("2") do |config|
        
        if PLATFORM == 'windows'
            
            # DOWNLOAD FROM
            # https://vagrantcloud-files-production.s3-accelerate.amazonaws.com/archivist/boxes/gusztavvargadr/windows-server-2025-standard-core/2601.0.0/libvirt
            
            # ADD WITH 
            # vagrant box add gusztavvargadr/windows-server-core ./e6a44741-ff98-11f0-afed-d26e708a301d --provider libvirt
            
            config.vm.box              = "gusztavvargadr/windows-server-core"
            # config.vm.box_version      = ">= 2202.0.0"
            
            config.vm.guest            = :windows
            config.vm.communicator     = "winrm"
            config.winrm.transport     = :negotiate
            config.winrm.basic_auth_only = false
            config.vm.boot_timeout     = 600   # Windows boots slower
            config.vm.graceful_halt_timeout = 120
        else
            config.vm.box          = "bento/ubuntu-24.04"
            config.vm.boot_timeout = 300
        end

        config.vm.synced_folder ".", "/vagrant", disabled: true    

        NODES.each do |name, cfg|
            config.vm.define name do |node|
                node.vm.hostname = cfg[:hostname]
                node.vm.network "private_network", ip: cfg[:ip]

                # ── Libvirt (Linux host) ────────────────────────────────────────────
                node.vm.provider "libvirt" do |lv|
                    lv.memory            = cfg[:memory]
                    lv.cpus              = cfg[:cpus]
                    lv.storage_pool_name = "images"
            
                    # Required for Hyper-V inside Windows guest (MCR Linux containers)
                    if PLATFORM == 'windows'
                        lv.nested            = true
                        lv.cpu_mode          = "host-passthrough"
                        # Expose Hyper-V enlightenments so Windows guest detects it correctly

                        lv.hyperv_feature name: 'relaxed',   state: 'on'
                        lv.hyperv_feature name: 'vapic',     state: 'on'
                        lv.hyperv_feature name: 'spinlocks', state: 'on', retries: '8191'
                    end
                end
            
                # ── VirtualBox (Windows host fallback) ─────────────────────────────
                node.vm.provider "virtualbox" do |vb|
                    vb.memory       = cfg[:memory]
                    vb.cpus         = cfg[:cpus]
                    vb.linked_clone = true
            
                    if PLATFORM == 'windows'
                        # Nested VT-x/AMD-V for Hyper-V inside guest
                        vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
                    end
                end

                # ═══════════════════════════════════════════════════════════════════
                # LINUX provisioning
                # ═══════════════════════════════════════════════════════════════════

                if PLATFORM == 'linux'
    
                    if name == "runner-builder"
                        node.vm.provision "configure_runner", type: "shell" do |s|
                            s.path   = "scripts/runner.sh"
                            s.binary = true
                            s.env    = { "REGISTRATION_TOKEN" => ENV['GITLAB_TOKEN'] }
                        end
                    end
        
                    if name == "production-node"
                        node.vm.provision "make_app_dir", type: "shell" do |s|
                                s.inline = <<~SHELL
                                sudo mkdir -p /app/nginx /app/monitoring \
                                    && sudo chown -R vagrant:vagrant /app
                            SHELL
                        end
                
                        node.vm.provision "file", source: "docker-compose.yml",                destination: "/app/docker-compose.yml"
                        node.vm.provision "file", source: "nginx/nginx.conf",                  destination: "/app/nginx/nginx.conf"
                        node.vm.provision "file", source: "monitoring/filebeat.yml",           destination: "/app/monitoring/filebeat.yml"
                        node.vm.provision "file", source: "monitoring/logstash.conf",          destination: "/app/monitoring/logstash.conf"
                        node.vm.provision "file", source: "monitoring/logstash-template.json", destination: "/app/monitoring/logstash-template.json"
                
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

                # ═══════════════════════════════════════════════════════════════════
                # WINDOWS provisioning
                # ═══════════════════════════════════════════════════════════════════
                elsif PLATFORM == 'windows'
        
                    if name == "runner-builder-win"
                        node.vm.provision "configure_runner_win", type: "shell",
                                        privileged: true, powershell_elevated_interactive: false do |s|
                            s.path = "scripts/runner-win.ps1"
                            s.env  = { "REGISTRATION_TOKEN" => ENV['GITLAB_TOKEN'] }
                        end
                    end
            
                    if name == "production-node-win"
                    # Copy compose + nginx config to guest before running provision script
                        node.vm.provision "file",
                            source:      "docker-compose.windows.yml",
                            destination: "C:/app/docker-compose.windows.yml"
                
                        node.vm.provision "file",
                            source:      "nginx/nginx.conf",
                            destination: "C:/app/nginx/nginx.conf"
                
                        node.vm.provision "configure_production_win", type: "shell",
                                            privileged: true, powershell_elevated_interactive: false do |s|
                            s.path = "scripts/production-win.ps1"
                            s.env  = {
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
    end
