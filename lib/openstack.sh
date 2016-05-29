function __configure_keystone()
{
	( openstack-config --set ${1} keystone_authtoken auth_uri http://${api_address}:5000
	openstack-config --set ${1} keystone_authtoken auth_url http://${api_address}:35357
	openstack-config --set ${1} keystone_authtoken memcached_servers ${api_address}:11211
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

function __openstack_images()
{
	print -n "Creating OpenStack images"

	if [[ ! -d /images ]]; then
		mkdir /images
	fi

	if [[ ! -f /images/cirros-0.3.4-x86_64-disk.img ]]; then
		( wget -c http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img -O /images/cirros-0.3.4-x86_64-disk.img ) > /dev/null 2>&1

	fi

	openstack image show CirrOS > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		( glance image-create --name "CirrOS" \
		  --file /images/cirros-0.3.4-x86_64-disk.img \
		  --container-format bare \
		  --disk-format qcow2 \
		  --visibility public ) > /dev/null 2>&1
	fi
}

function __openstack_flavors()
{
	print -n "Creating OpenStack flavors"

	openstack flavor show sandbox.tiny > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		openstack flavor create --ram=512 --disk=1 --vcpus=1 --public sandbox.tiny > /dev/null 2>&1
	fi
    # openstack flavor create --ram=2048 --disk=20 --vcpus=2 --private sandbox.tiny
    # openstack flavor create --ram=4096 --disk=20 --vcpus=4 --private sandbox.small
    # openstack flavor create --ram=8192 --disk=20 --vcpus=4 --private sandbox.medium

    # nova flavor-key sandbox.tiny set hw_rng:allowed=True
    # nova flavor-key sandbox.tiny set hw_rng:rate_bytes=100
    # nova flavor-key sandbox.tiny set hw_rng:rate_period=1

    # nova flavor-key sandbox.small set hw_rng:allowed=True
    # nova flavor-key sandbox.small set hw_rng:rate_bytes=100
    # nova flavor-key sandbox.small set hw_rng:rate_period=1

    # nova flavor-key sandbox.medium set hw_rng:allowed=True
    # nova flavor-key sandbox.medium set hw_rng:rate_bytes=100
    # nova flavor-key sandbox.medium set hw_rng:rate_period=1
}

function __openstack_keypairs()
{
	print -n "Creating OpenStack ssh keypairs"

	openstack keypair show default > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		nova keypair-add --pub-key ~/.ssh/id_rsa.pub default > /dev/null 2>&1
	fi
}

function __openstack_security_groups()
{
	print -n "Creating OpenStack security groups and rules"

	print -n "\tdefault"
	openstack security group rule list default | grep -q icmp > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		openstack security group rule create default --proto icmp > /dev/null 2>&1
	fi
	openstack security group rule list default | grep -q 22:22 > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		openstack security group rule create default --proto tcp --src-ip 0.0.0.0/0 --dst-port 22 > /dev/null 2>&1
	fi

	print -n "\tnfs-server"
	openstack security group show nfs-server > /dev/null 2>&1
	if [[ $? == 1 ]]; then
	    ( openstack security group create nfs-server --description 'NFS Server'
	    openstack security group rule create nfs-server --proto tcp --src-ip 0.0.0.0/0 --dst-port 111
	    openstack security group rule create nfs-server --proto udp --src-ip 0.0.0.0/0 --dst-port 111
	    openstack security group rule create nfs-server --proto tcp --src-ip 0.0.0.0/0 --dst-port 662
	    openstack security group rule create nfs-server --proto udp --src-ip 0.0.0.0/0 --dst-port 662
	    openstack security group rule create nfs-server --proto tcp --src-ip 0.0.0.0/0 --dst-port 892
	    openstack security group rule create nfs-server --proto udp --src-ip 0.0.0.0/0 --dst-port 892
	    openstack security group rule create nfs-server --proto tcp --src-ip 0.0.0.0/0 --dst-port 2049
	    openstack security group rule create nfs-server --proto udp --src-ip 0.0.0.0/0 --dst-port 2049
	    openstack security group rule create nfs-server --proto tcp --src-ip 0.0.0.0/0 --dst-port 32769
	    openstack security group rule create nfs-server --proto udp --src-ip 0.0.0.0/0 --dst-port 32769
	    openstack security group rule create nfs-server --proto tcp --src-ip 0.0.0.0/0 --dst-port 32803
	    openstack security group rule create nfs-server --proto udp --src-ip 0.0.0.0/0 --dst-port 32803 ) > /dev/null 2>&1
	fi
}

function __openstack_networks()
{
	print -n "Creating OpenStack networks"

	ADMIN_TENANT_ID=$(openstack project show admin -f value -c id)

	openstack network show ext-net > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		neutron net-create ext-net --router:external --provider:physical_network external --provider:network_type flat  > /dev/null 2>&1
	fi

	openstack subnet show ext-subnet > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		( neutron subnet-create ext-net 10.199.53.0/24 \
		    --allocation-pool start=10.199.53.101,end=10.199.53.200 \
		    --gateway 10.199.53.2 --disable-dhcp --name ext-subnet ) > /dev/null 2>&1
	fi

	openstack network show admin-net > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		neutron net-create admin-net --tenant-id ${ADMIN_TENANT_ID} --provider:network_type vxlan  > /dev/null 2>&1
	fi

	openstack subnet show admin-subnet > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		neutron subnet-create admin-net --name admin-subnet --gateway 192.168.1.1 192.168.1.0/24 > /dev/null 2>&1
	fi

	openstack router show admin-router > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		( neutron router-create admin-router
		neutron router-interface-add admin-router admin-subnet
		neutron router-gateway-set admin-router ext-net ) > /dev/null 2>&1
	fi
}

function __openstack_instance()
{
	print -n "Creating OpenStack test instance"
	true
# nova boot --image IMAGE_ID --flavor 1 --hint group=SERVER_GROUP_UUID server-1


# 	nova boot \
# 	--image CirrOS \
# 	--flavor sandbox.tiny \
# 	--key-name default
# 	--security-group default \
# 	testvm


# 	nova boot \
#   --flavor m1.tiny \
#   --block-device source=image,id=9d80c76c-6ff8-4212-8110-bbe9ead10460,dest=volume,size=2,shutdown=delete,bootindex=0 \
#   --nic net-id=427ca6fb-810b-4508-9c13-581fae07bc63 \
#   --security-group default \
#   --key-name coreos \
#   --availability-zone nova:kvm17.oadr \
#   test17

#   openstack server create \
#   	--flavor
#   	--key-name
#   	--

}

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
