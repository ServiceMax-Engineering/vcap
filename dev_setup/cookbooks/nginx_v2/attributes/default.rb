include_attribute "deployment"

default[:router][:config_file] = "router.yml"
#default[:router][:client_inactivity_timeout] = 60

default[:nginx_v2][:version] = "1.1.18"
default[:nginx_v2][:pcre_id]  = "eyJzaWciOiJidU8zVW4rMEE5SVpYdkIxakpTb1NmNkV4N0k9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMTFlMTIyMDA0ZTRlOGVjNjQ4NDMxMDUwMThmNDFjMDA1NWMi%0AfQ==%0A"
default[:nginx_v2][:module_upload_id]  = "eyJzaWciOiJNU2VoeXVtVTZabDQxaHNLT2xLTFhka2hpTVU9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIxMjA0ZTRlODZlZWJlNTkxMDUwMThmMmU0YWYzNTUi%0AfQ==%0A"
default[:nginx_v2][:module_headers_more_id]  = "eyJzaWciOiJHNmZUd092Wk03MTBIdWZGbTZsdVhlUkkvQkk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMjFlMTIxMDA0ZTRlN2Q1MTFmNTUzMDUwMThmM2I2YTEzMGQi%0AfQ==%0A"
default[:nginx_v2][:module_devel_kit_id]  = "eyJzaWciOiJPZ0dPL3BBbmszOS96MWYvWFNadm11bGZDNFk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIyMDA0ZTRlOGVjNjg0MDc3MDUwMThmM2FkYmExZmMi%0AfQ==%0A"
default[:nginx_v2][:module_lua_id]  = "eyJzaWciOiIrODdSUXRTbUFINm5Sd3NNcFc2YlFDSVNPUXM9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIyMDA0ZTRlOGVjNjg0MDc3MDUwMThmMmQ2ZGVhZTci%0AfQ==%0A"
default[:nginx_v2][:path]    = File.join(node[:deployment][:home], "deploy", "nginx", "nginx-#{nginx_v2[:version]}")
default[:nginx_v2][:vcap_log] = File.join(node[:deployment][:home], "sys", "log", "vcap.access.log")
default[:nginx_v2][:checksums][:source] = "bf040821f3ffa3c733e14894b427eed119316561ab6617e5f0b13aa6353aa3ae"
default[:nginx_v2][:checksums][:pcre_source] = "710d506ceb98305b2bd26ba93725acba03f8673765aba5a5598110cac7dbf5c3"
default[:nginx_v2][:checksums][:module_upload_source] = "b1c26abe0427180602e257627b4ed21848c93cc20cefc33af084983767d65805"
default[:nginx_v2][:checksums][:module_headers_more_source] = "10587007913805a5193e3104e81fd180a5c52bf7c3f5a5746081660916619bde"
default[:nginx_v2][:checksums][:module_devel_kit_source] = "bf5540d76d1867b4411091f16c6c786fd66759099c59483c76c68434020fdb02"
default[:nginx_v2][:checksums][:module_lua_source] = "0802110ee2428642baab24f2b8bd6d82c0396c4f9afd023b26534adfb48f5760"
default[:nginx_v2][:checksums][:module_sticky_source] = "6c18334d29d055bf9f21d59f9e9fb093e4dad017577f54b37c9358d315b05587"
default[:nginx_v2][:dh_params] = "dhparam2048.pem"

default[:lua][:version] = "5.1.4"
default[:lua][:simple_version] = lua[:version].match(/\d+\.\d+/).to_s # something like 5.1
default[:lua][:id]  = "eyJzaWciOiJrd0YvTVVmV24zb3pscHFHN0cwcXhQZ2RjV3c9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMzFlMTIyMjA0ZTRlOTg2M2IxYjc0MDUwMThmMjUzMTUyNzQi%0AfQ==%0A"
default[:lua][:path]    = File.join(node[:deployment][:home], "deploy", "lua", "lua-#{lua[:version]}")
default[:lua][:cjson_id]  = "eyJzaWciOiJ5OGp2YWlvUWptNXhrc3hTODdYQ0x0N0JXemM9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIxMjA0ZTRlODZlZWJlNTkxMDUwMThmMjViZGE3MDYi%0AfQ==%0A"
default[:lua][:module_path]    = File.join(lua[:path], 'lib', 'lua', lua[:simple_version])
default[:lua][:plugin_source_path] = File.join(node[:cloudfoundry][:path], "router", "ext", "nginx")


default[:lua][:checksums][:source] = "b038e225eaf2a5b57c9bcc35cd13aa8c6c8288ef493d52970c9545074098af3a"
default[:lua][:checksums][:cjson_source] = "9659fef3d4d3bc08b3fbd7827636dad6fb236c83d277b632879cb354f1b2e942"

default[:nginx_v2][:worker_connections] = 1024
default[:nginx_v2][:uls_ip] = "localhost"
default[:nginx_v2][:uls_port] = 8081
default[:nginx_v2][:log_home] = File.join(node[:deployment][:home], "log", "nginx")
default[:nginx_v2][:status_user] = "admin"
default[:nginx_v2][:status_passwd] = "password"

default[:router_v2][:session_key]    = "14fbc303b76bacd1e0a3ab641c11d11400341c5d"
default[:router_v2][:trace_key]    = "222"

default[:serialization_data_server][:upstream_port] = 2000
default[:snapshot][:dir] = "/var/vcap/snapshot"
