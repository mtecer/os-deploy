function install_cinder_api()
{
    print "Installing Cinder"

    ( rpm -q openstack-cinder || yum -y install openstack-cinder ) > /dev/null

    sed -i '/logdir/d' /usr/share/cinder/cinder-dist.conf

    sed -i 's/group:nobody//g' /etc/cinder/policy.json

    __configure_keystone ${cinder_config_file} cinder ${keystone_cinder_password}

    __configure_oslo_messaging_rabbit ${cinder_config_file}

    openstack-config --set ${cinder_config_file} DEFAULT verbose False
    openstack-config --set ${cinder_config_file} DEFAULT auth_strategy keystone
    openstack-config --set ${cinder_config_file} DEFAULT my_ip ${my_ip}
    openstack-config --set ${cinder_config_file} DEFAULT rpc_backend rabbit
    openstack-config --set ${cinder_config_file} DEFAULT glance_api_version 2

    openstack-config --set ${cinder_config_file} database connection mysql+pymysql://cinder:${mysql_cinder_password}@127.0.0.1/cinder

    openstack-config --set ${cinder_config_file} oslo_concurrency lock_path /var/lib/cinder/tmp

    openstack-config --set ${cinder_config_file} DEFAULT glance_api_servers http://${api_address}:9292

    openstack-config --set ${cinder_config_file} DEFAULT enabled_backends 'LVM'

    if [[ ! -d /var/lib/cinder/lock ]]; then
        mkdir /var/lib/cinder/lock
        chown cinder.cinder /var/lib/cinder/lock
    fi

    ( su -s /bin/sh -c "cinder-manage db sync" cinder ) > /dev/null 2>&1

    __enable_service openstack-cinder-api
    __enable_service openstack-cinder-scheduler
    # systemctl enable openstack-cinder-volume
    # systemctl enable openstack-cinder-backup

    __start_service openstack-cinder-api
    __start_service openstack-cinder-scheduler
    # systemctl restart openstack-cinder-volume
    # systemctl restart openstack-cinder-backup

    echo "export OS_VOLUME_API_VERSION=2" | tee -a /root/admin-openrc.sh

    print -s "DONE"
}
