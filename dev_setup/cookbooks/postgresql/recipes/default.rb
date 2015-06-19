#
# Cookbook Name:: postgresql
# Recipe:: default
#
# Copyright 2011, VMware
#
#
#

require 'digest'

#this would always install the latest version of postgres.
#for now we keep it under our control
#%w[libpq-dev postgresql].each do |pkg|
#  package pkg
#end

postgres_etc_install_folder="/etc/postgresql/#{node[:postgresql_node][:version]}"


case node['platform']
when "ubuntu"
  # Ugly and to the point... Should spend time improving the actual postgresql package
  # not fixing this.
  bash "Install postgres-#{node[:postgresql_node][:version]}" do
    code <<-EOH
POSTGRES_MAJOR_VERSION="#{node[:postgresql_node][:version]}"
echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" > etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

sudo apt-get update
apt-get install -qy postgresql-$POSTGRES_MAJOR_VERSION postgresql-contrib-$POSTGRES_MAJOR_VERSION libpq-dev libpq5
EOH
    not_if do
      ::File.exists?(postgres_etc_install_folder)
    end
  end.run_action(:run)
  
  template "/etc/init.d/postgresql with upstart events when postgres starts and stops" do
    path "/etc/init.d/postgresql"
    source "etc_initd_postgresql.erb"
    mode 0755
  end

  
  ruby_block "postgresql_conf_update" do
    block do
      pg_major_version = node[:postgresql_node][:version]

      # update postgresql.conf
      postgresql_conf_file = File.join("", "etc", "postgresql", pg_major_version, "main", "postgresql.conf")
      pg_hba_file = File.join("", "etc", "postgresql", pg_major_version, "main", "pg_hba.conf")
      postgresql_conf_file_digest=Digest::SHA256.file(postgresql_conf_file).hexdigest
      pg_hba_file_digest=Digest::SHA256.file(pg_hba_file).hexdigest
      
      `grep "^\s*listen_addresses" #{postgresql_conf_file}`
      if $?.exitstatus != 0
        #This command is easy but it inserts it at the very end which is surprising to the sys admin.
        #let's look for the usually commented out line
        #and e=insert below it. if we can't find it then we will append.
        `grep "^\s*#listen_addresses" #{postgresql_conf_file}`
        if $?.exitstatus != 0
          `sed -i "/^\s*#listen_addresses.*/a \listen_addresses='#{node[:postgresql_node][:listen_addresses]}'" #{postgresql_conf_file}`
        else
          `echo "listen_addresses='#{node[:postgresql_node][:listen_addresses]}'" >> #{postgresql_conf_file}`
        end
      else
        `sed -i.bkup -e "s/^\s*listen_addresses.*$/listen_addresses='#{node[:postgresql_node][:listen_addresses]}'/" #{postgresql_conf_file}`
      end

      `grep "^\s*lo_compat_privileges" #{postgresql_conf_file}`
      if $?.exitstatus != 0
        #This command is easy but it inserts it at the very end which is surprising to the sys admin.
        #let's look for the usually commented out line
        #and e=insert below it. if we can't find it then we will append.
        `grep "^\s*#lo_compat_privileges" #{postgresql_conf_file}`
        if $?.exitstatus != 0
          `sed -i "/^\s*#lo_compat_privileges.*/a \lo_compat_privileges=on" #{postgresql_conf_file}`
        else
          `echo "lo_compat_privileges=on" >> #{postgresql_conf_file}`
        end
      else
        `sed -i.bkup -e "s/^\s*lo_compat_privileges.*$/lo_compat_privileges=on/" #{postgresql_conf_file}`
      end

      # update the local psql connections to psotgres.
      unless node[:postgresql_node][:local_acl].nil?
        #replace 'local   all             all                                     peer'
        #by      'local   all             all                                     #{}'
`sed -i 's/^local[ \t]*all[ \t]*all[ \t]*[a-z]*[ \t]*$/local   all             all                                     #{node[:postgresql_node][:local_acl]}/g' #{pg_hba_file}`
      end
      postgresql_conf_file_digest_after=Digest::SHA256.file(postgresql_conf_file).hexdigest
      pg_hba_file_digest_after=Digest::SHA256.file(pg_hba_file).hexdigest
      if postgresql_conf_file_digest_after != postgresql_conf_file_digest ||
          pg_hba_file_digest_after != pg_hba_file_digest
        Chef::Log.warn("Restarting postgresql server as the configuration files have changed")
        pg_server_command 'restart'
      end
    end
  end
  
  # make sure template1 uses UTF encoding and locale:
  cf_pg_setup_template()
  
  # configure ltree.sql with some extensions:
  if node[:postgresql_node][:extensions_in_template1]
    extension_names=node[:postgresql_node][:extensions_in_template1].split(',')
    extension_names.each do |extension_name|
      cf_pg_setup_extension(extension_name.strip)
    end
  else
    Chef::Log.warn("not configuring ltree on template1 #{node[:postgresql_node][:ltree_in_template1]}")
  end
  
  cf_pg_server_command 'reload'
  
else
  Chef::Log.error("Installation of PostgreSQL is not supported on this platform.")
end

# Add the current IP to the allowed ones
#The network/if-up.d script takes care of changing this IP by a new one when it changes
# and i we decide to track a particular network interface.
cf_pg_update_hba_conf("all", "all", "#{cf_local_ip} 255.255.255.255", "md5") if cf_local_ip != '127.0.0.1'

if node[:postgresql_node][:pg_hba_extra]
  #relax the rules to connect to postgres.
  cf_pg_update_hba_conf(node[:postgresql_node][:pg_hba_extra][:database], node[:postgresql_node][:pg_hba_extra][:user], node[:postgresql_node][:pg_hba_extra][:ip_range], node[:postgresql_node][:pg_hba_extra][:pass_encrypt])
end

cf_pg_update_hba_conf(node[:postgresql_node][:database], node[:postgresql_node][:server_root_user])
cf_pg_setup_db(node[:postgresql_node][:database],
               node[:postgresql_node][:server_root_user],
               node[:postgresql_node][:server_root_password],
               'SUPERUSER', # superuser necessary to read pg_stat_activity see http://blog.kimiensoftware.com/2011/05/querying-pg_stat_activity-and-insufficient-privilege-291
               'CREATEDB CREATEROLE', # will create the roles and databases for postgresnode,
               'template1',
               # the extra grants are not necessary now that we are a superuser.
               [ "GRANT SELECT ON pg_authid to #{node[:postgresql_node][:server_root_user]}" ])


# we need database root for cleaning up error message in postgresql log file
cf_pg_setup_db('root',
               node[:postgresql_node][:server_root_user],
               node[:postgresql_node][:server_root_password],
               'SUPERUSER', # superuser necessary to read pg_stat_activity see http://blog.kimiensoftware.com/2011/05/querying-pg_stat_activity-and-insufficient-privilege-291
               'CREATEDB CREATEROLE', # will create the roles and databases for postgresnode,
               'template1',
               # the extra grants are not necessary now that we are a superuser.
               [ "GRANT SELECT ON pg_authid to #{node[:postgresql_node][:server_root_user]}" ])
