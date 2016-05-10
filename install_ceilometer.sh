function install_ceilometer_api()
{
    print "Installing Ceilometer API"

    ( rpm -q openstack-ceilometer-api openstack-ceilometer-collector openstack-ceilometer-notification openstack-ceilometer-central || yum -y openstack-ceilometer-api openstack-ceilometer-collector openstack-ceilometer-notification openstack-ceilometer-central python-ceilometerclient ) > /dev/null

    __configure_keystone ${ceilometer_config_file} ceilometer ${keystone_ceilometer_password}

    __configure_service_credentials ${ceilometer_config_file} ceilometer ${keystone_ceilometer_password}

    __configure_oslo_messaging_rabbit ${ceilometer_config_file}

    openstack-config --set ${ceilometer_config_file} DEFAULT auth_strategy keystone
    openstack-config --set ${ceilometer_config_file} DEFAULT rpc_backend rabbit

    openstack-config --set ${ceilometer_config_file} database connection mongodb://ceilometer:${mysql_ceilometer_password}@127.0.0.1:27017/ceilometer

    openstack-config --set ${ceilometer_config_file} publisher telemetry_secret $metering_secret

    openstack-config --set ${ceilometer_config_file} service_credentials auth_url http://${api_address}:35357
    openstack-config --set ${ceilometer_config_file} service_credentials auth_type password
    openstack-config --set ${ceilometer_config_file} service_credentials project_domain_name default
    openstack-config --set ${ceilometer_config_file} service_credentials user_domain_name default
    openstack-config --set ${ceilometer_config_file} service_credentials project_name service
    openstack-config --set ${ceilometer_config_file} service_credentials username ceilometer
    openstack-config --set ${ceilometer_config_file} service_credentials password ${keystone_ceilometer_password}
    openstack-config --set ${ceilometer_config_file} service_credentials interface internalURL
    openstack-config --set ${ceilometer_config_file} service_credentials region_name RegionOne

    sed -i 's/interval: 600/interval: 30/g' /etc/ceilometer/pipeline.yaml

    __enable_service openstack-ceilometer-api
    __enable_service openstack-ceilometer-notification
    __enable_service openstack-ceilometer-central
    __enable_service openstack-ceilometer-collector

    __start_service openstack-ceilometer-api
    __start_service openstack-ceilometer-notification
    __start_service openstack-ceilometer-central
    __start_service openstack-ceilometer-collector

    __configure_oslo_messaging_rabbit ${glance_api_config_file}

    ( systemctl is-active openstack-ceilometer-api openstack-ceilometer-notification openstack-ceilometer-central openstack-ceilometer-collector ) > /dev/null  2>&1
    if [[ $? != 0 ]]; then
        openstack-config --set ${glance_api_config_file} DEFAULT rpc_backend rabbit

        openstack-config --set ${glance_api_config_file} oslo_messaging_notifications driver messagingv2

        __restart_service openstack-glance-api
        __restart_service openstack-glance-registry

        openstack-config --set /etc/cinder/cinder.conf oslo_messaging_notifications driver messagingv2

        __restart_service openstack-cinder-api.service
        __restart_service openstack-cinder-scheduler.service
        __restart_service openstack-cinder-volume.service

        openstack-config --set /etc/neutron/neutron.conf oslo_messaging_notifications driver messagingv2

        __restart_service neutron-server
    fi

    print -s "DONE"
}

function install_ceilometer_compute()
{
    print "Installing Ceilometer Compute"

    ( rpm -q openstack-ceilometer-compute || yum -y openstack-ceilometer-compute python-ceilometerclient python-pecan ) > /dev/null

    __configure_keystone ${ceilometer_config_file} ceilometer ${keystone_ceilometer_password}

    __configure_oslo_messaging_rabbit ${ceilometer_config_file}

    openstack-config --set ${ceilometer_config_file} DEFAULT auth_strategy keystone
    openstack-config --set ${ceilometer_config_file} DEFAULT rpc_backend rabbit

    openstack-config --set ${ceilometer_config_file} service_credentials os_auth_url http://${api_address}:5000
    openstack-config --set ${ceilometer_config_file} service_credentials os_username ceilometer
    openstack-config --set ${ceilometer_config_file} service_credentials os_tenant_name service
    openstack-config --set ${ceilometer_config_file} service_credentials os_password ${keystone_ceilometer_password}
    openstack-config --set ${ceilometer_config_file} service_credentials interface internalURL
    openstack-config --set ${ceilometer_config_file} service_credentials region_name RegionOne

    sed -i 's/interval: 600/interval: 30/g' /etc/ceilometer/pipeline.yaml

    openstack-config --set ${nova_config_file} DEFAULT instance_usage_audit True
    openstack-config --set ${nova_config_file} DEFAULT instance_usage_audit_period hour
    openstack-config --set ${nova_config_file} DEFAULT notify_on_state_change vm_and_task_state
    openstack-config --set ${nova_config_file} DEFAULT notification_driver messagingv2

    __enable_service openstack-ceilometer-compute
    __start_service openstack-ceilometer-compute

    __restart_service openstack-nova-compute

    print -s "DONE"
}