#
# Cookbook Name:: postgresql
# Recipe:: default
#
# Copyright 2011, VMware
#
#
#

#this would always install the latest version of postgres.
#for now we keep it under our control
#%w[libpq-dev postgresql].each do |pkg|
#  package pkg
#end

case node['platform']
when "ubuntu"
  # Ugly and to the point... Should spend time improving the actual postgresql package
  # not fixing this.
  bash "Install postgres-#{node[:postgresql_node][:version]}" do
    code <<-EOH
POSTGRES_MAJOR_VERSION="#{node[:postgresql_node][:version]}"
if [ ! -d "/etc/postgresql/$POSTGRES_MAJOR_VERSION" ]; then
  apt-get install -qy python-software-properties
  add-apt-repository ppa:pitti/postgresql
  apt-get -qy update
  apt-get install -qy postgresql-$POSTGRES_MAJOR_VERSION postgresql-contrib-$POSTGRES_MAJOR_VERSION
  apt-get install -qy postgresql-server-dev-$POSTGRES_MAJOR_VERSION libpq-dev libpq5
fi
EOH
  end.run_action(:run)
  
  ruby_block "postgresql_conf_update" do
    block do
      / \d*.\d*/ =~ `pg_config --version`
      pg_major_version = $&.strip

      # update postgresql.conf
      postgresql_conf_file = File.join("", "etc", "postgresql", pg_major_version, "main", "postgresql.conf")
      `grep "^\s*listen_addresses" #{postgresql_conf_file}`
      if $?.exitstatus != 0
        #This command is easy but it inserts it at the very end which is surprising to the sys admin.
        #let's look for the usually commented out line
        #and e=insert below it. if we can't find it then we will append.
        `grep "^\s*#listen_addresses" #{postgresql_conf_file}`
        if $?.exitstatus != 0
          `sed -i "/^\s*#listen_addresses.*/a \listen_addresses='#{node[:postgresql_node][:host]}'" #{postgresql_conf_file}`
        else
          `echo "listen_addresses='#{node[:postgresql_node][:host]},localhost'" >> #{postgresql_conf_file}`
        end
      else
        `sed -i.bkup -e "s/^\s*listen_addresses.*$/listen_addresses='#{node[:postgresql_node][:listen_addresses]}'/" #{postgresql_conf_file}`
      end
      
      # update the local psql connections to psotgres.
      unless node[:postgresql_node][:local_acl].nil?
        pg_hba_file = File.join("", "etc", "postgresql", pg_major_version, "main", "pg_hba.conf")
        #replace 'local   all             all                                     peer'
        #by 'local   all             all                                     #{}'
        `sed -i 's/^local[ \t]*all[ \t]*all[ \t]*[a-z]*[ \t]*$/local   all             all                                     #{node[:postgresql_node][:local_acl]}/g' #{pg_hba_file}`
      end
      pg_server_command 'restart'
    end
  end
  # configure ltree.sql with some extensions:
  if node[:postgresql_node][:extensions_in_template1]
    extension_names=node[:postgresql_node][:extensions_in_template1].split(',')
    extension_names.each do |extension_name|
      cf_pg_setup_extension(extension_name.strip)
    end
  else
    `echo not configuring ltree on template1 #{node[:postgresql_node][:ltree_in_template1]}`
  end
  
  cf_pg_server_command 'reload'
  
else
  Chef::Log.error("Installation of PostgreSQL is not supported on this platform.")
end

# Add the current IP to the allowed ones
cf_pg_update_hba_conf("all", "all", "#{cf_local_ip} 255.255.255.255", "md5") unless cf_local_ip == '127.0.0.1'

unless node[:postgresql_node][:pg_hba_extra].nil?
  #relax the rules to connect to postgres.
  cf_pg_update_hba_conf(node[:postgresql_node][:pg_hba_extra][:database], node[:postgresql_node][:pg_hba_extra][:user], node[:postgresql_node][:pg_hba_extra][:ip_range], node[:postgresql_node][:pg_hba_extra][:pass_encrypt])
end

cf_pg_update_hba_conf(node[:postgresql_node][:database], node[:postgresql_node][:server_root_user])
cf_pg_setup_db(node[:postgresql_node][:database], node[:postgresql_node][:server_root_user], node[:postgresql_node][:server_root_password])


