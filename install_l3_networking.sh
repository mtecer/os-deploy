function deploy_l3_vlan_infrastructure_controller()
{
    openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
    openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router
    openstack-config --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True

    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan,vxlan
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vlan,vxlan
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch,l2population
    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security

    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks external

    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vlan network_vlan_ranges external,vlan

    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 65537:69999

    openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver iptables_hybrid
}

function deploy_l3_vlan_infrastructure_network()
{
    local tunnel_ip=$(ifconfig ${vxlan_nic} | grep inet | awk '{ print $2 }')

    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip ${tunnel_ip}
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings vlan:br-vlan,external:br-ex

    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types vxlan
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population True

    openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
    openstack-config --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge

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

    __add_ovs_bridge_port br-tun ${vxlan_nic}
    __add_ovs_bridge_port br-ex ${ext_nic}
    __add_ovs_bridge_port br-vlan ${vlan_nic}

    __enable_service neutron-openvswitch-agent
    __start_service neutron-openvswitch-agent

    __enable_service neutron-l3-agent
    __enable_service neutron-metadata-agent
    __enable_service neutron-netns-cleanup
    __enable_service neutron-ovs-cleanup
    __enable_service neutron-dhcp-agent

    __start_service neutron-l3-agent
    __start_service neutron-metadata-agent
    __start_service neutron-dhcp-agent

}

function deploy_l3_vlan_infrastructure_compute()
{
    local tunnel_ip=$(ifconfig ${vxlan_nic} | grep inet | awk '{ print $2 }')

    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip ${tunnel_ip}
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings vlan:br-vlan

    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types vxlan
    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population True

    openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver iptables_hybrid

    __enable_service openvswitch
    __start_service openvswitch

    __add_ovs_bridge_port br-tun ${vxlan_nic}
    __add_ovs_bridge_port br-vlan ${vlan_nic}

    __enable_service neutron-openvswitch-agent
    __start_service neutron-openvswitch-agent

    __enable_service neutron-metadata-agent
    __enable_service neutron-netns-cleanup
    __enable_service neutron-ovs-cleanup

    __start_service neutron-metadata-agent
}
