#
# Cookbook Name:: nginx-new
# Recipe:: default
#
# Copyright 2011, VMware
#
#

template node[:router][:config_file] do
  path File.join(node[:deployment][:config_path], node[:router][:config_file])
  source "router.yml.erb"
  owner node[:deployment][:user]
  mode 0644
  notifies :restart, "service[vcap_router]"
end

nginx_version = node[:nginx_v2][:version]
nginx_path = node[:nginx_v2][:path]
lua_version = node[:lua][:version]
lua_path = node[:lua][:path]
lua_module_path = node[:lua][:module_path]
router_path = File.join(node[:cloudfoundry][:path], "router")

case node['platform']
when "ubuntu"

  template "openssl-gen-conf.cnf" do
    path File.join(node[:deployment][:config_path], "openssl-gen-conf.cnf")
    source "openssl-gen-conf.cnf.erb"
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode 0755
  end
  bash "generate the ssl self signed cert" do
    # mysterious failure to start nginx with the latest beta build of 12.04 if something is echoed out.
    code <<-CMD
    export CLOUD_FOUNDRY_CONFIG_PATH=#{node[:deployment][:config_path]}
    echo "CLOUD_FOUNDRY_CONFIG_PATH $CLOUD_FOUNDRY_CONFIG_PATH"
    bash -x #{node[:cloudfoundry][:path]}/dev_setup/bin/vcap_generate_ssl_cert_self_signed
    CMD
    notifies :restart, "service[nginx_router]"
    not_if do
      ::File.exists?(File.join(node[:nginx][:ssl][:config_dir],node[:nginx][:ssl][:basename]+".crt"))
    end
  end

  %w[ build-essential].each do |pkg|
    package pkg
  end

  # don't make and reinstall nginx+lua if it was already done.
  unless File.exists?(nginx_path) && File.exists?(lua_module_path) &&  File.exists?(lua_path)

    # Lua related packages
    ::FileUtils.mkdir_p node[:deployment][:setup_cache]
    lua_tarball = File.join(node[:deployment][:setup_cache], "lua-#{lua_version}.tar.gz")
    cf_remote_file lua_tarball do
      owner node[:deployment][:user]
      id node[:lua][:id]
      checksum node[:lua][:checksums][:source]
    end

    lua_cjson_tarball = File.join(node[:deployment][:setup_cache], "lua-cjson-1.0.3.tar.gz")
    cf_remote_file lua_cjson_tarball do
      owner node[:deployment][:user]
      id node[:lua][:cjson_id]
      checksum node[:lua][:checksums][:cjson_source]
    end

    # Nginx related packages
    nginx_tarball = File.join(node[:deployment][:setup_cache], "nginx-#{nginx_version}.tar.gz")
    remote_file nginx_tarball do
      owner node[:deployment][:user]
      source "http://nginx.org/download/nginx-#{nginx_version}.tar.gz"
      checksum node[:nginx_v2][:checksums][:source]
      action :create_if_missing
    end

    pcre_tarball = File.join(node[:deployment][:setup_cache], "pcre-8.12.tar.gz")
    cf_remote_file pcre_tarball do
      owner node[:deployment][:user]
      id node[:nginx_v2][:pcre_id]
      checksum node[:nginx_v2][:checksums][:pcre_source]
    end

    nginx_upload_module_tarball = File.join(node[:deployment][:setup_cache], "nginx_upload_module-2.2.0.tar.gz")
    cf_remote_file nginx_upload_module_tarball do
      owner node[:deployment][:user]
      id node[:nginx_v2][:module_upload_id]
      checksum node[:nginx_v2][:checksums][:module_upload_source]
    end

    headers_more_tarball = File.join(node[:deployment][:setup_cache], "headers-more-v0.15rc1.tar.gz")
    cf_remote_file headers_more_tarball do
      owner node[:deployment][:user]
      id node[:nginx_v2][:module_headers_more_id]
      checksum node[:nginx_v2][:checksums][:module_headers_more_source]
    end

    devel_kit_tarball = File.join(node[:deployment][:setup_cache], "devel-kit-v0.2.17rc2.tar.gz")
    cf_remote_file devel_kit_tarball do
      owner node[:deployment][:user]
      id node[:nginx_v2][:module_devel_kit_id]
      checksum node[:nginx_v2][:checksums][:module_devel_kit_source]
    end

    nginx_lua_tarball = File.join(node[:deployment][:setup_cache], "lua-nginx-module-0.5.13.tar.gz")
    remote_file nginx_lua_tarball do
      owner node[:deployment][:user]
      source "https://github.com/openresty/lua-nginx-module/archive/v0.5.13.tar.gz"
      checksum node[:nginx_v2][:checksums][:module_lua_source]
      action :create_if_missing
    end
	
    nginx_sticky_module = File.join(node[:deployment][:setup_cache], "nginx-sticky-module-1.1.tar.gz")
    remote_file nginx_sticky_module do
      owner node[:deployment][:user]
      source "https://nginx-sticky-module.googlecode.com/files/nginx-sticky-module-1.1.tar.gz"
      checksum node[:nginx_v2][:checksums][:module_sticky_source]
      action :create_if_missing
    end

    directory nginx_path do
      owner node[:deployment][:user]
      group node[:deployment][:group]
      mode "0755"
      recursive true
      action :create
    end

    directory node[:nginx_v2][:log_home] do
      owner node[:deployment][:user]
      group node[:deployment][:group]
      mode "0755"
      recursive true
      action :create
    end

    directory lua_path do
      owner node[:deployment][:user]
      group node[:deployment][:group]
      mode "0755"
      recursive true
      action :create
    end

    bash "Install lua" do
      cwd File.join("", "tmp")
      user node[:deployment][:user]
      code <<-EOH
        tar xzf #{lua_tarball}
        cd lua-#{lua_version}
        make linux install INSTALL_TOP=#{lua_path}
      EOH
    end

    bash "Install lua json" do
      cwd File.join("", "tmp")
      user node[:deployment][:user]
      code <<-EOH
        tar xzf #{lua_cjson_tarball}
        cd lua-cjson-1.0.3
        sed 's!^PREFIX ?=.*!PREFIX ?='#{lua_path}'!' Makefile > tmp
        mv tmp Makefile
        make
        make install
      EOH
    end

    bash "Install nginx" do
      cwd File.join("", "tmp")
      user node[:deployment][:user]
      code <<-EOH
        tar xzf #{nginx_tarball}
        tar xzf #{pcre_tarball}
        tar xzf #{nginx_upload_module_tarball}
        tar xzf #{headers_more_tarball}
        tar xzf #{devel_kit_tarball}
        tar xzf #{nginx_lua_tarball}
        tar xzf #{nginx_sticky_module}

        [ -d chunkin-nginx-module ] && rm -rf chunkin-nginx-module
        git clone https://github.com/agentzh/chunkin-nginx-module.git --depth 1

        cd nginx-#{nginx_version}

        LUA_LIB=#{lua_path}/lib LUA_INC=#{lua_path}/include ./configure \
          --prefix=#{nginx_path} \
          --with-pcre=../pcre-8.12 \
          --with-cc-opt=-Wno-unused-but-set-variable \
          --with-http_ssl_module \
          --add-module=../chunkin-nginx-module \
          --add-module=../nginx_upload_module-2.2.0 \
          --add-module=../headers-more-v0.15rc1 \
          --add-module=../simpl-ngx_devel_kit-bc97eea \
          --add-module=../lua-nginx-module-0.5.13 \
          --add-module=../nginx-sticky-module-1.1

        make
        make install
      EOH
    end
  end # don't make and reinstall nginx+lua if it was already done.

  # for now delete the repo first.
  #::FileUtils.rm_rf router_path if ::File.exists?(router_path)

  #git router_path do
    #repository node[:cloudfoundry][:git][:router][:repo]
    #revision node[:cloudfoundry][:git][:router][:branch]
    #depth 1
    #action :sync
    #user node[:deployment][:user]
    #group node[:deployment][:group]
  #end

  cf_bundle_install(router_path)
  add_to_vcap_components("router")


  template "uls.lua" do
    path File.join(lua_module_path, "uls.lua")
    source File.join(node[:lua][:plugin_source_path], "uls.lua")
    local true
    owner node[:deployment][:user]
    mode 0644
  end

  template "tablesave.lua" do
    path File.join(lua_module_path, "tablesave.lua")
    source File.join(node[:lua][:plugin_source_path], "tablesave.lua")
    local true
    owner node[:deployment][:user]
    mode 0644
  end

  template "nginx_router.conf" do
    path File.join(nginx_path, "conf", "nginx_router.conf")
    source "router-nginx.conf.erb"
    owner node[:deployment][:user]
    mode 0644
  end

  template "nginx_router" do
    path File.join("", "etc", "init.d", "nginx_router")
    source "router-nginx.erb"
    owner node[:deployment][:user]
    mode 0755
  end

# For now we don't do the nginx_cc and nginx_sds
=begin
  template "nginx_cc.conf" do
    path File.join(nginx_path, "conf", "nginx_cc.conf")
    source "cc-nginx.conf.erb"
    owner node[:deployment][:user]
    mode 0644
  end

  template "nginx_cc" do
    path File.join("", "etc", "init.d", "nginx_cc")
    source "cc-nginx.erb"
    owner node[:deployment][:user]
    mode 0755
  end

  template "nginx_sds.conf" do
    path File.join(nginx_path, "conf", "nginx_sds.conf")
    source "sds-nginx.conf.erb"
    owner node[:deployment][:user]
    mode 0644
  end

  template "nginx_sds" do
    path File.join("", "etc", "init.d", "nginx_sds")
    source "sds-nginx.erb"
    owner node[:deployment][:user]
    mode 0755
  end
=end

  bash "Install dhparam2048" do
    code <<-CMD
    sudo openssl dhparam -out #{node[:nginx][:ssl][:config_dir]}/#{node[:nginx_v2][:dh_params]} 2048
    CMD
    notifies :restart, "service[nginx_router]"
    not_if do
      ::File.exists?(File.join(node[:nginx][:ssl][:config_dir], node[:nginx_v2][:dh_params]))
    end
  end

  bash "Add *.servicemax.local hostnames to /etc/host" do
    # This is needed for nginx config for port routing to resolve correctly 
    code <<-EOH
      servicemax_host=`grep "servicemax.local" /etc/hosts`
      if [ -z "$servicemax_host" ]; then
        sudo sed -i '$a #Do NOT remove! This is needed for nginx config for port routing to resolve correctly' /etc/hosts
        sudo sed -i '$a 127.0.0.1 api.intalio.priv db.intalio.priv servicemax.local oauth.servicemax.local admin.servicemax.local cdn.servicemax.local' /etc/hosts
      fi
    EOH
  end

  service "nginx_router" do
    supports :status => true, :restart => true, :reload => false, :start => true, :stop => true
    action [ :enable, :restart ]
  end

  service "vcap_router" do
    provider CloudFoundry::VCapChefService
    supports :status => true, :restart => true, :start => true, :stop => true
    action [ :start ]
  end


# For now we don't do nginx_cc and nginx_sds
=begin
  service "nginx_cc" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :restart ]
  end

  service "nginx_sds" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :restart ]
  end
=end

else
  Chef::Log.error("Installation of nginx packages not supported on this platform.")
end
