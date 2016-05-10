function install_manila_api()
{
    print "Installing Manila API"

    ( rpm -q openstack-manila python-manilaclient openstack-manila-ui || yum -y install openstack-manila python-manilaclient openstack-manila-ui ) > /dev/null

    __configure_keystone ${manila_config_file} manila ${keystone_manila_password}

    __configure_oslo_messaging_rabbit ${manila_config_file}

    openstack-config --set ${manila_config_file} DEFAULT verbose False

    openstack-config --set ${manila_config_file} DEFAULT auth_strategy keystone
    openstack-config --set ${manila_config_file} DEFAULT default_share_type default_share_type
    openstack-config --set ${manila_config_file} DEFAULT my_ip ${my_ip}
    openstack-config --set ${manila_config_file} DEFAULT rootwrap_config /etc/manila/rootwrap.conf
    openstack-config --set ${manila_config_file} DEFAULT rpc_backend rabbit

    openstack-config --set ${manila_config_file} DEFAULT default_log_levels amqp=WARN,amqplib=WARN,boto=WARN,qpid=WARN,sqlalchemy=WARN,suds=INFO,oslo.messaging=INFO,iso8601=WARN,requests.packages.urllib3.connectionpool=WARN,urllib3.connectionpool=WARN,websocket=WARN,requests.packages.urllib3.util.retry=WARN,urllib3.util.retry=WARN,keystonemiddleware=WARN,routes.middleware=WARN,stevedore=WARN,taskflow=WARN,keystoneauth=WARN,oslo.cache=INFO,dogpile.core.dogpile=INFO,manila.context=ERROR

    openstack-config --set ${manila_config_file} database connection mysql+pymysql://manila:${mysql_manila_password}@127.0.0.1/manila

    openstack-config --set ${manila_config_file} oslo_concurrency lock_path /var/lib/manila/tmp

    ( su -s /bin/sh -c "manila-manage db sync" manila ) > /dev/null 2>&1

    __enable_service openstack-manila-api
    __enable_service openstack-manila-scheduler

    __start_service openstack-manila-api
    __start_service openstack-manila-scheduler

    print -s "DONE"
}
