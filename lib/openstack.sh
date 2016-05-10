function __configure_keystone()
{
    ( openstack-config --set ${1} keystone_authtoken auth_uri http://${api_address}:5000
    openstack-config --set ${1} keystone_authtoken auth_url http://${api_address}:35357
    openstack-config --set ${1} keystone_authtoken memcached_servers 127.0.0.1:11211
    openstack-config --set ${1} keystone_authtoken auth_type password
    openstack-config --set ${1} keystone_authtoken project_domain_name default
    openstack-config --set ${1} keystone_authtoken user_domain_name default
    openstack-config --set ${1} keystone_authtoken project_name service
    openstack-config --set ${1} keystone_authtoken username ${2}
    openstack-config --set ${1} keystone_authtoken password ${3}
    openstack-config --set ${1} keystone_authtoken signing_dir /var/lib/${2}/keystone-signing

    mkdir /var/lib/${2}/keystone-signing
    chown ${2}.${2} /var/lib/${2}/keystone-signing
    chmod 700 /var/lib/${2}/keystone-signing ) > /dev/null 2>&1
}

function __configure_service_credentials()
{
    openstack-config --set ${1} service_credentials auth_url http://${api_address}:35357
    openstack-config --set ${1} service_credentials auth_type password
    openstack-config --set ${1} service_credentials project_domain_name default
    openstack-config --set ${1} service_credentials user_domain_name default
    openstack-config --set ${1} service_credentials project_name service
    openstack-config --set ${1} service_credentials username ${2}
    openstack-config --set ${1} service_credentials password ${3}
    openstack-config --set ${1} service_credentials interface internalURL
    openstack-config --set ${1} service_credentials region_name RegionOne
}

function __configure_oslo_messaging_rabbit()
{
    openstack-config --set ${1} oslo_messaging_rabbit rabbit_host ${rabbitmq_host}
    openstack-config --set ${1} oslo_messaging_rabbit rabbit_userid ${rabbitmq_userid}
    openstack-config --set ${1} oslo_messaging_rabbit rabbit_password ${rabbitmq_password}
}

function __add_ovs_bridge_port()
{
    ( ovs-vsctl br-exists ${1} && ovs-vsctl port-to-br ${2} ) > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        ovs-vsctl add-br ${1} && ovs-vsctl add-port ${1} ${2}
        ovs-vsctl br-set-external-id ${1} bridge-id ${1}
    fi
}

# function __openstack_flavors()
# {
#     openstack flavor create --ram=2048 --disk=20 --vcpus=2 --private sandbox.tiny
#     openstack flavor create --ram=4096 --disk=20 --vcpus=4 --private sandbox.small
#     openstack flavor create --ram=8192 --disk=20 --vcpus=4 --private sandbox.medium

#     nova flavor-key sandbox.tiny set hw_rng:allowed=True
#     nova flavor-key sandbox.tiny set hw_rng:rate_bytes=100
#     nova flavor-key sandbox.tiny set hw_rng:rate_period=1

#     nova flavor-key sandbox.small set hw_rng:allowed=True
#     nova flavor-key sandbox.small set hw_rng:rate_bytes=100
#     nova flavor-key sandbox.small set hw_rng:rate_period=1

#     nova flavor-key sandbox.medium set hw_rng:allowed=True
#     nova flavor-key sandbox.medium set hw_rng:rate_bytes=100
#     nova flavor-key sandbox.medium set hw_rng:rate_period=1
# }

# function __openstack_security_groups()
# {
#     openstack security group create nfs-server --description 'NFS Server'
#     openstack security group rule create nfs-server --proto tcp --src-ip 0.0.0.0/0 --dst-port 111
#     openstack security group rule create nfs-server --proto udp --src-ip 0.0.0.0/0 --dst-port 111
#     openstack security group rule create nfs-server --proto tcp --src-ip 0.0.0.0/0 --dst-port 662
#     openstack security group rule create nfs-server --proto udp --src-ip 0.0.0.0/0 --dst-port 662
#     openstack security group rule create nfs-server --proto tcp --src-ip 0.0.0.0/0 --dst-port 892
#     openstack security group rule create nfs-server --proto udp --src-ip 0.0.0.0/0 --dst-port 892
#     openstack security group rule create nfs-server --proto tcp --src-ip 0.0.0.0/0 --dst-port 2049
#     openstack security group rule create nfs-server --proto udp --src-ip 0.0.0.0/0 --dst-port 2049
#     openstack security group rule create nfs-server --proto tcp --src-ip 0.0.0.0/0 --dst-port 32769
#     openstack security group rule create nfs-server --proto udp --src-ip 0.0.0.0/0 --dst-port 32769
#     openstack security group rule create nfs-server --proto tcp --src-ip 0.0.0.0/0 --dst-port 32803
#     openstack security group rule create nfs-server --proto udp --src-ip 0.0.0.0/0 --dst-port 32803
# }

# function __openstack_networks()
# {
#     neutron net-create --shared admin --provider:network_type flat --provider:physical_network admin

#     neutron subnet-create admin 10.199.54.0/24 --name admin-subnet \
#       --allocation-pool start=10.199.54.2,end=10.199.54.254 --gateway 10.199.54.1 \
#       --enable_dhcp=True

#     openstack network list --long
#     openstack subnet list --long

#     neutron subnet-update admin-subnet --dns_nameservers list=true 10.199.54.11 10.199.54.10

#     neutron net-list-on-dhcp-agent 4fd338ea-0d92-4cc1-815d-f8b530abd3aa

#     neutron dhcp-agent-list-hosting-net admin

#     neutron net-create --shared net51 --provider:network_type vlan --provider:physical_network vlans --provider:segmentation_id 51
#     neutron subnet-create net51 172.16.51.0/24 --name net51-subnet --enable_dhcp=True

#     neutron net-create --shared net52 --provider:network_type vlan --provider:physical_network vlans --provider:segmentation_id 52
#     neutron subnet-create net52 172.16.52.0/24 --name net52-subnet --enable_dhcp=True

#     neutron net-create --shared net53 --provider:network_type vlan --provider:physical_network vlans --provider:segmentation_id 53
#     neutron subnet-create net53 172.16.53.0/24 --name net53-subnet --enable_dhcp=True

#     neutron net-create --shared net58 --provider:network_type vlan --provider:physical_network vlans --provider:segmentation_id 58
#     neutron subnet-create net58 172.16.58.0/24 --name net58-subnet --enable_dhcp=True

#     neutron net-create --shared net59 --provider:network_type vlan --provider:physical_network vlans --provider:segmentation_id 59
#     neutron subnet-create net59 172.16.59.0/24 --name net59-subnet --enable_dhcp=True

#     openstack network list --long
#     openstack subnet list --long

#     neutron ext-list
#     neutron agent-list
# }
