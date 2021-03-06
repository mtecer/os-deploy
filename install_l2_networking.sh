function deploy_l2_vlan_infrastructure_controller()
{
    __ml2_config_file='/etc/neutron/plugins/ml2/ml2_conf.ini'
    __ovs_config_file='/etc/neutron/plugins/ml2/openvswitch_agent.ini'

    openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
    openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router

    # ML2
    #  [ml2]
    openstack-config --set ${__ml2_config_file} ml2 type_drivers 'vlan,vxlan'
    openstack-config --set ${__ml2_config_file} ml2 tenant_network_types 'vxlan'
    openstack-config --set ${__ml2_config_file} ml2 mechanism_drivers 'openvswitch,l2population'
    openstack-config --set ${__ml2_config_file} ml2 extension_drivers 'port_security'
    #  [ml2_type_vlan]
    openstack-config --set ${__ml2_config_file} ml2_type_vlan network_vlan_ranges 'provider'
    #  [ml2_type_vxlan]
    openstack-config --set ${__ml2_config_file} ml2_type_vxlan vni_ranges '4096:16777215'
    openstack-config --set ${__ml2_config_file} ml2_type_vxlan vxlan_group '224.0.0.1'
    #  [securitygroup]
    openstack-config --set ${__ml2_config_file} securitygroup enable_ipset 'True'
    openstack-config --set ${__ml2_config_file} securitygroup firewall_driver iptables_hybrid
    openstack-config --set ${__ml2_config_file} securitygroup enable_security_group 'True'

    # OpenVSWitch
    #  [agent]
    openstack-config --set ${__ovs_config_file} agent tunnel_types 'vxlan'
    openstack-config --set ${__ovs_config_file} agent l2_population 'True'
    #  [ovs]
    openstack-config --set ${__ovs_config_file} ovs local_ip "$(hostname --ip-address)"
    openstack-config --set ${__ovs_config_file} ovs bridge_mappings 'provider:br-provider'
    #  [securitygroup]
    openstack-config --set ${__ovs_config_file} securitygroup firewall_driver 'iptables_hybrid'
    openstack-config --set ${__ovs_config_file} securitygroup enable_security_group 'True'

    # DHCP
    openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
    openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata True
    openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_lease_duration 120

    # Metadata
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip ${api_address}
    openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret ${metadata_proxy_shared_secret}

    # L3
    openstack-config --set ${neutron_config_file} DEFAULT l3_ha 'True'
    openstack-config --set ${neutron_config_file} DEFAULT allow_automatic_l3agent_failover 'True'
    openstack-config --set ${neutron_config_file} DEFAULT min_l3_agents_per_router '2'
    openstack-config --set ${neutron_config_file} DEFAULT max_l3_agents_per_router '2'

    openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver 'neutron.agent.linux.interface.OVSInterfaceDriver'
    openstack-config --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge

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
    __enable_service neutron-l3-agent

    __start_service neutron-metadata-agent
    __start_service neutron-dhcp-agent
    __start_service neutron-l3-agent

}

function deploy_l2_vlan_infrastructure_compute()
{
    __ml2_config_file='/etc/neutron/plugins/ml2/ml2_conf.ini'
    __ovs_config_file='/etc/neutron/plugins/ml2/openvswitch_agent.ini'

    # OpenVSWitch
    #  [agent]
    openstack-config --set ${__ovs_config_file} agent tunnel_types 'vxlan'
    openstack-config --set ${__ovs_config_file} agent l2_population 'True'
    #  [ovs]
    openstack-config --set ${__ovs_config_file} ovs local_ip "$(hostname --ip-address)"
    openstack-config --set ${__ovs_config_file} ovs bridge_mappings 'provider:br-provider'
    #  [securitygroup]
    openstack-config --set ${__ovs_config_file} securitygroup firewall_driver 'iptables_hybrid'
    openstack-config --set ${__ovs_config_file} securitygroup enable_security_group 'True'

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
