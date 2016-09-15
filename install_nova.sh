function __configure_neutron_in_nova()
{
    openstack-config --set /etc/nova/nova.conf neutron url http://${api_address}:9696
    openstack-config --set /etc/nova/nova.conf neutron auth_url ${protocol}://${api_address}:35357
    openstack-config --set /etc/nova/nova.conf neutron auth_type password
    openstack-config --set /etc/nova/nova.conf neutron project_domain_name default
    openstack-config --set /etc/nova/nova.conf neutron user_domain_name default
    openstack-config --set /etc/nova/nova.conf neutron region_name RegionOne
    openstack-config --set /etc/nova/nova.conf neutron project_name service
    openstack-config --set /etc/nova/nova.conf neutron username ${1}
    openstack-config --set /etc/nova/nova.conf neutron password ${2}
}

function install_nova_api()
{
    print "Installing Nova API"

    ( rpm -q openstack-nova-api openstack-nova-cert openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler || yum -y -q install openstack-nova-api openstack-nova-cert openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler ) > /dev/null

    __configure_keystone ${nova_config_file} nova ${keystone_nova_password}

    __configure_neutron_in_nova neutron ${keystone_neutron_password}

    __configure_oslo_messaging_rabbit ${nova_config_file}

    openstack-config --set ${nova_config_file} DEFAULT enabled_apis 'osapi_compute,metadata'
    openstack-config --set ${nova_config_file} DEFAULT auth_strategy keystone
    openstack-config --set ${nova_config_file} DEFAULT my_ip ${my_ip}
    openstack-config --set ${nova_config_file} DEFAULT use_neutron True
    openstack-config --set ${nova_config_file} DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
    openstack-config --set ${nova_config_file} DEFAULT rpc_backend rabbit
    openstack-config --set ${nova_config_file} DEFAULT dhcp_domain ${dhcp_domain_name}

    openstack-config --set ${nova_config_file} DEFAULT osapi_compute_listen 127.0.0.1
    openstack-config --set ${nova_config_file} DEFAULT metadata_listen 127.0.0.1

    openstack-config --set ${nova_config_file} DEFAULT scheduler_default_filters 'RetryFilter,AvailabilityZoneFilter,RamFilter,DiskFilter,ComputeFilter,ComputeCapabilitiesFilter,ImagePropertiesFilter,ServerGroupAntiAffinityFilter,ServerGroupAffinityFilter,NUMATopologyFilter,AggregateInstanceExtraSpecsFilter'

    openstack-config --set ${nova_config_file} DEFAULT default_log_levels 'amqp=WARN,amqplib=WARN,boto=WARN,qpid=WARN,sqlalchemy=WARN,suds=WARN,oslo.messaging=WARN,iso8601=WARN,requests.packages.urllib3.connectionpool=WARN,urllib3.connectionpool=WARN,websocket=WARN,requests.packages.urllib3.util.retry=WARN,urllib3.util.retry=WARN,keystonemiddleware=WARN,routes.middleware=WARN,stevedore=WARN,taskflow=WARN,keystoneauth=WARN,oslo.cache=WARN,dogpile.core.dogpile=WARN,nova=WARN'

    openstack-config --set ${nova_config_file} api_database connection "mysql+pymysql://nova:${mysql_nova_password}@${api_address}/nova_api"

    openstack-config --set ${nova_config_file} cinder os_region_name RegionOne

    openstack-config --set ${nova_config_file} database connection "mysql+pymysql://nova:${mysql_nova_password}@${api_address}/nova"

    openstack-config --set ${nova_config_file} glance api_servers http://${api_address}:9292

    openstack-config --set ${nova_config_file} neutron service_metadata_proxy True
    openstack-config --set ${nova_config_file} neutron metadata_proxy_shared_secret ${metadata_proxy_shared_secret}

    openstack-config --set ${nova_config_file} oslo_concurrency lock_path /var/lib/nova/tmp

    openstack-config --set ${nova_config_file} vnc vncserver_listen '$my_ip'
    openstack-config --set ${nova_config_file} vnc vncserver_proxyclient_address '$my_ip'
    openstack-config --set ${nova_config_file} vnc novncproxy_host 127.0.0.1

    ( su -s /bin/sh -c "nova-manage api_db sync" nova ) > /dev/null 2>&1
    ( su -s /bin/sh -c "nova-manage db sync" nova ) > /dev/null 2>&1

    __enable_service openstack-nova-api
    __enable_service openstack-nova-consoleauth
    __enable_service openstack-nova-scheduler
    __enable_service openstack-nova-conductor
    __enable_service openstack-nova-novncproxy

    __start_service openstack-nova-api
    __start_service openstack-nova-consoleauth
    __start_service openstack-nova-scheduler
    __start_service openstack-nova-conductor
    __start_service openstack-nova-novncproxy

    print -s "DONE"
}

function install_nova_compute()
{
    print "Installing Nova Compute"

    __aggregate=$(hostname -s)

    __generate_openrc

    rpm -q qemu-img-rhev > /dev/null 2>&1
    if [[ $? == 0 ]]; then
        ( rpm -e libcacard-devel-rhev libcacard-rhev libcacard-tools-rhev qemu-img-rhev qemu-kvm-common-rhev qemu-kvm-rhev qemu-kvm-rhev-debuginfo qemu-kvm-tools-rhev --nodeps  ) > /dev/null 2>&1
    fi

    ( rpm -q openstack-nova-compute || yum -y -q install qemu-img-ev qemu-kvm-common-ev qemu-kvm-ev qemu-kvm-tools-ev openstack-nova-compute sysfsutils openstack-utils numactl ) > /dev/null 2>&1

    __configure_keystone ${nova_config_file} nova ${keystone_nova_password}

    __configure_neutron_in_nova neutron ${keystone_neutron_password}

    __configure_oslo_messaging_rabbit ${nova_config_file}

    openstack-config --set ${nova_config_file} DEFAULT auth_strategy keystone
    openstack-config --set ${nova_config_file} DEFAULT my_ip ${my_ip}
    openstack-config --set ${nova_config_file} DEFAULT use_neutron True
    openstack-config --set ${nova_config_file} DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
    openstack-config --set ${nova_config_file} DEFAULT rpc_backend rabbit

    openstack-config --set ${nova_config_file} DEFAULT default_log_levels 'amqp=WARN,amqplib=WARN,boto=WARN,qpid=WARN,sqlalchemy=WARN,suds=WARN,oslo.messaging=WARN,iso8601=WARN,requests.packages.urllib3.connectionpool=WARN,urllib3.connectionpool=WARN,websocket=WARN,requests.packages.urllib3.util.retry=WARN,urllib3.util.retry=WARN,keystonemiddleware=WARN,routes.middleware=WARN,stevedore=WARN,taskflow=WARN,keystoneauth=WARN,oslo.cache=WARN,dogpile.core.dogpile=WARN,nova=WARN'

    if [[ ${vcpu_pin_set} ]]; then
        openstack-config --set ${nova_config_file} DEFAULT vcpu_pin_set ${vcpu_pin_set}
    else
        openstack-config --del ${nova_config_file} DEFAULT vcpu_pin_set
    fi

    openstack-config --set ${nova_config_file} glance api_servers http://${api_address}:9292

    openstack-config --set ${nova_config_file} oslo_concurrency lock_path /var/lib/nova/tmp

    openstack-config --set ${nova_config_file} vnc enabled True
    openstack-config --set ${nova_config_file} vnc vncserver_listen '0.0.0.0'
    openstack-config --set ${nova_config_file} vnc vncserver_proxyclient_address '$my_ip'
    openstack-config --set ${nova_config_file} vnc novncproxy_base_url "http://${api_address}:6080/vnc_auto.html"

    sed -i -e 's/#listen_tls = 0/listen_tls = 0/g' \
        -e 's/#listen_tcp = 1/listen_tcp = 1/g' \
        -e 's/#listen_addr = "192.168.0.1"/listen_addr = "0.0.0.0"/g' \
        -e 's/#tcp_port = "16509"/tcp_port = "16509"/g' \
        -e 's/#auth_tcp = "sasl"/auth_tcp = "none"/g' \
        /etc/libvirt/libvirtd.conf

    sed -i -e 's/#LIBVIRTD_ARGS="--listen"/LIBVIRTD_ARGS="--listen"/g' \
        /etc/sysconfig/libvirtd

    __enable_service libvirtd
    __enable_service openstack-nova-compute

    __start_service libvirtd
    __start_service openstack-nova-compute

    ( openstack aggregate show ${__aggregate} ) > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        ( openstack aggregate create ${__aggregate} --zone ${__aggregate}
         openstack aggregate add host ${__aggregate} $(hostname) ) > /dev/null 2>&1
    fi

    print -s "DONE"
}