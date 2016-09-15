function install_cinder()
{
    print "Installing Cinder"

    ( rpm -q openstack-cinder || yum -y install openstack-cinder python-keystonemiddleware ) > /dev/null

    sed -i '/logdir/d' /usr/share/cinder/cinder-dist.conf

    sed -i 's/group:nobody//g' /etc/cinder/policy.json

    __configure_keystone ${cinder_config_file} cinder ${keystone_cinder_password}

    __configure_oslo_messaging_rabbit ${cinder_config_file}

    openstack-config --set ${cinder_config_file} DEFAULT auth_strategy keystone
    openstack-config --set ${cinder_config_file} DEFAULT my_ip ${my_ip}
    openstack-config --set ${cinder_config_file} DEFAULT rpc_backend rabbit
    openstack-config --set ${cinder_config_file} DEFAULT glance_api_version 2

    openstack-config --set ${cinder_config_file} DEFAULT default_log_levels 'amqp=WARN,amqplib=WARN,boto=WARN,qpid=WARN,sqlalchemy=WARN,suds=WARN,oslo.messaging=WARN,iso8601=WARN,requests.packages.urllib3.connectionpool=WARN,urllib3.connectionpool=WARN,websocket=WARN,requests.packages.urllib3.util.retry=WARN,urllib3.util.retry=WARN,keystonemiddleware=WARN,routes.middleware=WARN,stevedore=WARN,taskflow=WARN,keystoneauth=WARN,oslo.cache=WARN,dogpile.core.dogpile=WARN'

    openstack-config --set ${cinder_config_file} database connection mysql+pymysql://cinder:${mysql_cinder_password}@${api_address}/cinder

    openstack-config --set ${cinder_config_file} oslo_concurrency lock_path /var/lib/cinder/tmp

    openstack-config --set ${cinder_config_file} DEFAULT glance_api_servers http://${api_address}:9292

    if [[ ! -d /var/lib/cinder/lock ]]; then
        mkdir /var/lib/cinder/lock
        chown cinder.cinder /var/lib/cinder/lock
    fi

    print -s "DONE"
}
