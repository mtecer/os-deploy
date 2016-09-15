function deploy_l2_vlan_infrastructure_controller()
{
    openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
    openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router

    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security

    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks provider

    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vlan network_vlan_ranges provider

    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver iptables_hybrid

    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings provider:br-provider

    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver iptables_hybrid

    openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
    openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata True
    openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_lease_duration 120

    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip ${api_address}
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret ${metadata_proxy_shared_secret}

    ( su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
      --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron ) > /dev/null 2>&1

    __enable_service neutron-server
    __start_service neutron-server

    __enable_service openvswitch
    __start_service openvswitch

    _md5sum_original=$(md5sum /etc/sysconfig/network-scripts/ifcfg-br-provider)
    (   echo 'DEVICE="br-provider"'
        echo 'ONBOOT="yes"'
        echo 'DEVICETYPE="ovs"'
        echo 'TYPE="OVSBridge"'
        echo 'BOOTPROTO="none"'
        echo 'HOTPLUG="no"'
     ) > /etc/sysconfig/network-scripts/ifcfg-br-provider
    _md5sum_updated=$(md5sum /etc/sysconfig/network-scripts/ifcfg-br-provider)

    if [[ ${_md5sum_original} != ${_md5sum_updated} ]]; then
        __restart_service network
    fi

    __enable_service neutron-openvswitch-agent
    __start_service neutron-openvswitch-agent

    __enable_service neutron-metadata-agent
    __enable_service neutron-netns-cleanup
    __enable_service neutron-ovs-cleanup
    __enable_service neutron-dhcp-agent

    __start_service neutron-metadata-agent
    __start_service neutron-dhcp-agent

}

function deploy_l2_vlan_infrastructure_compute()
{
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings provider:br-provider

    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver iptables_hybrid

    __enable_service openvswitch
    __start_service openvswitch

    _md5sum_original=$(md5sum /etc/sysconfig/network-scripts/ifcfg-br-provider)
    (   echo 'DEVICE="br-provider"'
        echo 'ONBOOT="yes"'
        echo 'DEVICETYPE="ovs"'
        echo 'TYPE="OVSBridge"'
        echo 'BOOTPROTO="none"'
        echo 'HOTPLUG="no"'
     ) > /etc/sysconfig/network-scripts/ifcfg-br-provider
    _md5sum_updated=$(md5sum /etc/sysconfig/network-scripts/ifcfg-br-provider)

    if [[ ${_md5sum_original} != ${_md5sum_updated} ]]; then
        __restart_service network
    fi

    __enable_service neutron-openvswitch-agent
    __enable_service neutron-netns-cleanup
    __enable_service neutron-ovs-cleanup

    __start_service neutron-openvswitch-agent
}
