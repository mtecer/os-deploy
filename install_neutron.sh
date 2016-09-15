function __configure_nova_in_neutron()
{
    openstack-config --set /etc/neutron/neutron.conf nova auth_url ${protocol}://${api_address}:35357
    openstack-config --set /etc/neutron/neutron.conf nova auth_type password
    openstack-config --set /etc/neutron/neutron.conf nova project_domain_name default
    openstack-config --set /etc/neutron/neutron.conf nova user_domain_name default
    openstack-config --set /etc/neutron/neutron.conf nova region_name RegionOne
    openstack-config --set /etc/neutron/neutron.conf nova project_name service
    openstack-config --set /etc/neutron/neutron.conf nova username ${1}
    openstack-config --set /etc/neutron/neutron.conf nova password ${2}
}

# function cleanup_openstack_networks()
# {
#     systemctl status neutron-openvswitch-agent
#     systemctl status openvswitch
#     systemctl status neutron-server
#     systemctl status neutron-dhcp-agent
#     systemctl status neutron-metadata-agent

#     systemctl stop neutron-openvswitch-agent
#     systemctl stop openvswitch
#     systemctl stop neutron-server
#     systemctl stop neutron-dhcp-agent
#     systemctl stop neutron-metadata-agent

#     rm -vf /etc/openvswitch/{conf.db,.conf.db.~lock~,system-id.conf}

#     ls -la /etc/openvswitch/

#     systemctl restart neutron-server
#     systemctl restart openvswitch
#     systemctl restart neutron-openvswitch-agent
#     systemctl restart neutron-dhcp-agent
#     systemctl restart neutron-metadata-agent
# }

function install_neutron_api()
{
    print "Installing Neutron API"

    ( rpm -q openstack-neutron openstack-neutron-ml2 || yum -y -q install openstack-neutron openstack-neutron-ml2 python-neutronclient openstack-neutron-openvswitch ipset which ebtables ) > /dev/null

    sed -i '/^verbose/d' /usr/share/neutron/neutron-dist.conf
    sed -i '/^notification_driver/d' /usr/share/neutron/neutron-dist.conf

    __configure_keystone ${neutron_config_file} neutron ${keystone_neutron_password}

    __configure_nova_in_neutron nova ${keystone_nova_password}

    __configure_oslo_messaging_rabbit ${neutron_config_file}

    openstack-config --set ${neutron_config_file} DEFAULT auth_strategy keystone
    openstack-config --set ${neutron_config_file} DEFAULT core_plugin ml2
    openstack-config --set ${neutron_config_file} DEFAULT notify_nova_on_port_status_changes True
    openstack-config --set ${neutron_config_file} DEFAULT notify_nova_on_port_data_changes True
    openstack-config --set ${neutron_config_file} DEFAULT rpc_backend rabbit
    openstack-config --set ${neutron_config_file} DEFAULT service_plugins router

    openstack-config --set ${neutron_config_file} DEFAULT bind_host 127.0.0.1

    openstack-config --set ${neutron_config_file} DEFAULT default_log_levels 'amqp=WARN,amqplib=WARN,boto=WARN,qpid=WARN,sqlalchemy=WARN,suds=WARN,oslo.messaging=WARN,iso8601=WARN,requests.packages.urllib3.connectionpool=WARN,urllib3.connectionpool=WARN,websocket=WARN,requests.packages.urllib3.util.retry=WARN,urllib3.util.retry=WARN,keystonemiddleware=WARN,routes.middleware=WARN,stevedore=WARN,taskflow=WARN,keystoneauth=WARN,oslo.cache=WARN,dogpile.core.dogpile=WARN,neutron.wsgi=WARN'

    openstack-config --set ${neutron_config_file} database connection "mysql+pymysql://neutron:${mysql_neutron_password}@${api_address}/neutron"

    openstack-config --set ${neutron_config_file} oslo_concurrency lock_path /var/lib/neutron/lock

    ( mkdir /var/lib/neutron/lock
    chown neutron.neutron /var/lib/neutron/lock
    chmod 700 /var/lib/neutron/lock ) > /dev/null 2>&1

    if [[ ! -e /etc/neutron/plugin.ini ]]; then
        ( ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini ) > /dev/null 2>&1
    fi

    if [[ ${1} == "L3" ]]; then
        deploy_l3_vlan_infrastructure_controller
        deploy_l3_vlan_infrastructure_network
    elif [[ ${1} == "L2" ]]; then
        deploy_l2_vlan_infrastructure_controller
    fi

    print -s "DONE"
}

function install_neutron_compute()
{
    print "Installing Neutron Compute"

    ( rpm -q openstack-neutron openstack-neutron-ml2 || yum -y -q install openstack-neutron openstack-neutron-ml2 python-neutronclient openstack-neutron-openvswitch ipset which ebtables ) > /dev/null

    sed -i '/^verbose/d' /usr/share/neutron/neutron-dist.conf
    sed -i '/^notification_driver/d' /usr/share/neutron/neutron-dist.conf

    __configure_keystone ${neutron_config_file} neutron ${keystone_neutron_password}

    __configure_nova_in_neutron nova ${keystone_nova_password}

    __configure_oslo_messaging_rabbit ${neutron_config_file}

    openstack-config --set ${neutron_config_file} DEFAULT auth_strategy keystone
    openstack-config --set ${neutron_config_file} DEFAULT core_plugin ml2
    openstack-config --set ${neutron_config_file} DEFAULT notify_nova_on_port_status_changes True
    openstack-config --set ${neutron_config_file} DEFAULT notify_nova_on_port_data_changes True
    openstack-config --set ${neutron_config_file} DEFAULT rpc_backend rabbit
    openstack-config --set ${neutron_config_file} DEFAULT service_plugins router

    openstack-config --set ${neutron_config_file} DEFAULT default_log_levels 'amqp=WARN,amqplib=WARN,boto=WARN,qpid=WARN,sqlalchemy=WARN,suds=WARN,oslo.messaging=WARN,iso8601=WARN,requests.packages.urllib3.connectionpool=WARN,urllib3.connectionpool=WARN,websocket=WARN,requests.packages.urllib3.util.retry=WARN,urllib3.util.retry=WARN,keystonemiddleware=WARN,routes.middleware=WARN,stevedore=WARN,taskflow=WARN,keystoneauth=WARN,oslo.cache=WARN,dogpile.core.dogpile=WARN,neutron.wsgi=WARN'

    openstack-config --set ${neutron_config_file} database connection "mysql+pymysql://neutron:${mysql_neutron_password}@${api_address}/neutron"

    openstack-config --set ${neutron_config_file} oslo_concurrency lock_path /var/lib/neutron/lock

    ( mkdir /var/lib/neutron/lock
    chown neutron.neutron /var/lib/neutron/lock
    chmod 700 /var/lib/neutron/lock ) > /dev/null 2>&1

    if [[ ${1} == "L3" ]]; then
        deploy_l3_vlan_infrastructure_compute
    elif [[ ${1} == "L2" ]]; then
        deploy_l2_vlan_infrastructure_compute
    fi

    print -s "DONE"
}
