function install_heat()
{
    print "Installing Heat"

    ( rpm -q openstack-heat-api openstack-heat-api-cfn openstack-heat-engine || yum -y install openstack-heat-api openstack-heat-api-cfn openstack-heat-engine python2-magnumclient python-manilaclient python-designateclient python-mistralclient python-zaqarclient ) > /dev/null

    __configure_keystone ${heat_config_file} heat ${keystone_heat_password}

    __configure_oslo_messaging_rabbit ${heat_config_file}

    openstack-config --set ${heat_config_file} DEFAULT rpc_backend rabbit

    openstack-config --set ${heat_config_file} DEFAULT heat_metadata_server_url http://${api_address}:8000
    openstack-config --set ${heat_config_file} DEFAULT heat_waitcondition_server_url http://${api_address}:8000/v1/waitcondition

    openstack-config --set ${heat_config_file} DEFAULT stack_domain_admin heat_domain_admin
    openstack-config --set ${heat_config_file} DEFAULT stack_domain_admin_password ${keystone_heat_domain_admin_password}
    openstack-config --set ${heat_config_file} DEFAULT stack_user_domain_name heat

    openstack-config --set ${heat_config_file} DEFAULT default_log_levels 'amqp=WARN,amqplib=WARN,boto=WARN,qpid=WARN,sqlalchemy=WARN,suds=WARN,oslo.messaging=WARN,iso8601=WARN,requests.packages.urllib3.connectionpool=WARN,urllib3.connectionpool=WARN,websocket=WARN,requests.packages.urllib3.util.retry=WARN,urllib3.util.retry=WARN,keystonemiddleware=WARN,routes.middleware=WARN,stevedore=WARN,taskflow=WARN,keystoneauth=WARN,oslo.cache=WARN,dogpile.core.dogpile=WARN'

    openstack-config --set ${heat_config_file} clients_keystone auth_uri ${protocol}://${api_address}:35357

    openstack-config --set ${heat_config_file} database connection "mysql+pymysql://heat:${mysql_heat_password}@${api_address}/heat"

    openstack-config --set ${heat_config_file} ec2authtoken auth_uri ${protocol}://${api_address}:5000

    openstack-config --set ${heat_config_file} trustee auth_plugin password
    openstack-config --set ${heat_config_file} trustee auth_url ${protocol}://${api_address}:35357
    openstack-config --set ${heat_config_file} trustee username heat
    openstack-config --set ${heat_config_file} trustee password ${keystone_heat_password}
    openstack-config --set ${heat_config_file} trustee user_domain_name default

    ( su -s /bin/sh -c "heat-manage db_sync" heat ) > /dev/null 2>&1

    __enable_service openstack-heat-api
    __enable_service openstack-heat-api-cfn
    __enable_service openstack-heat-engine

    __start_service openstack-heat-api
    __start_service openstack-heat-api-cfn
    __start_service openstack-heat-engine

    print -s "DONE"
}
