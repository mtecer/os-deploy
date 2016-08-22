function __generate_password()
{
	echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9_-' | fold -w 20 | egrep '^[a-zA-Z]' | head -n 1)
}

function __verify_role()
{
	if [[ -z $ROLE ]]; then
		ROLE=${1};
	else
		echo "ERROR: You can only assign one role to each server"
		exit 1
	fi
}

function print()
{
	if [[ ${1} == "-s" ]]; then
		echo -e "\e[0;32m${2}\e[0m"
	elif [[ ${1} == "-e" ]]; then
		echo -e "\e[0;31m${2}\e[0m"
	elif [[ ${1} == "-n" ]]; then
		echo -e "\e[0;31m${2} ... \e[0m"
	else
		echo -n -e "\e[0;34m${1} ... \e[0m"
	fi
}

function __enable_service()
{
	( systemctl is-enabled ${1} || systemctl enable ${1} ) > /dev/null  2>&1
}

function __start_service()
{
	( systemctl is-active ${1} || ( systemctl start ${1} && sleep 3 ) ) > /dev/null  2>&1
}

function __restart_service()
{
	( systemctl restart ${1} && sleep 3 ) > /dev/null  2>&1
}

function __cleanup_systemd_permissions()
{
	find /usr/lib/systemd/system -maxdepth 1 -type f -perm 755 -exec chmod 644 {} \;
}

function __finish_installation()
{
	__openstack_images
	__openstack_flavors
	__openstack_keypairs
	__openstack_security_groups
	__openstack_networks
	__openstack_instance
	__cleanup_systemd_permissions
	echo ""
    print -s " **** Installation completed succesfully **** "
	echo ""
	echo "Additional Information:"
	echo " * To access the OpenStack Dashboard browse to : ${protocol}://${api_address}"
	echo " * You can find your credentials in the admin-openrc.sh in your home directory"
}

function __generate_config_file()
{
	if [[ $NETWORKING == "" ]]; then
		echo "ERROR: Please specify networking with -n. Possible options are L2 or L3"
		exit 1
	fi

	if [[ -f ./os-deploy.config ]]; then
		echo "ERROR: There is already a configuration file in the current directory: os-deploy.config"
		exit 1
	else
		cat <<-HERE > ./os-deploy.config
		MANAGEMENT_NIC="eth0"
		VXLAN_NIC="eth1"
		EXT_NIC="eth2"
		VLAN_NIC="eth3"

		NETWORKING=${NETWORKING}
		PROXY=${PROXY}

		VXLAN_NETWORK="10.199.52.0"
		VLAN_NETWORK="10.199.54.0"

		API_ADDRESS='10.199.51.10'
		# API_ADDRESS=$(hostname --ip-address)
		# MY_IP=$(hostname --ip-address)
		# HOSTNAME=$(hostname)

		TLS=${TLS}
		PROTOCOL=${PROTOCOL}

		ADMIN_TOKEN=$(openssl rand -hex 20)
		METERING_SECRET=$(openssl rand -hex 10)
		METADATA_PROXY_SHARED_SECRET=$(openssl rand -hex 25)

		CINDER_ISCSI_DRIVE='/dev/sdb'
		CINDER_ISCSI_PARTITION='/dev/sdb1'
		MANILA_ISCSI_DRIVE='/dev/sdc'
		MANILA_ISCSI_PARTITION='/dev/sdc1'

		MYSQL_AODH_PASSWORD=$(__generate_password)
		MYSQL_CINDER_PASSWORD=$(__generate_password)
		MYSQL_DESIGNATE_PASSWORD=$(__generate_password)
		MYSQL_GLANCE_PASSWORD=$(__generate_password)
		MYSQL_HEAT_PASSWORD=$(__generate_password)
		MYSQL_KEYSTONE_PASSWORD=$(__generate_password)
		MYSQL_MANILA_PASSWORD=$(__generate_password)
		MYSQL_MURANO_PASSWORD=$(__generate_password)
		MYSQL_NEUTRON_PASSWORD=$(__generate_password)
		MYSQL_NOVA_PASSWORD=$(__generate_password)
		MYSQL_ROOT_PASSWORD=$(__generate_password)

		MONGOD_CEILOMETER_PASSWORD=$(__generate_password)

		KEYSTONE_ADMIN_PASSWORD=$(__generate_password)
		KEYSTONE_AODH_PASSWORD=$(__generate_password)
		KEYSTONE_CEILOMETER_PASSWORD=$(__generate_password)
		KEYSTONE_CINDER_PASSWORD=$(__generate_password)
		KEYSTONE_DESIGNATE_PASSWORD=$(__generate_password)
		KEYSTONE_GLANCE_PASSWORD=$(__generate_password)
		KEYSTONE_HEAT_PASSWORD=$(__generate_password)
		KEYSTONE_HEAT_DOMAIN_ADMIN_PASSWORD=$(__generate_password)
		KEYSTONE_MANILA_PASSWORD=$(__generate_password)
		KEYSTONE_MURANO_PASSWORD=$(__generate_password)
		KEYSTONE_NEUTRON_PASSWORD=$(__generate_password)
		KEYSTONE_NOVA_PASSWORD=$(__generate_password)

		RABBITMQ_USERID="openstack"
		RABBITMQ_PASSWORD=$(__generate_password)

		NTP_SERVERS=(
						'0.centos.pool.ntp.org'
						'1.centos.pool.ntp.org'
						'2.centos.pool.ntp.org'
						'3.centos.pool.ntp.org'
					)

		DHCP_DOMAIN_NAME='sandbox.sc9b'

		AODH_CONFIG_FILE="/etc/aodh/aodh.conf"
		CEILOMETER_CONFIG_FILE="/etc/ceilometer/ceilometer.conf"
		CINDER_CONFIG_FILE="/etc/cinder/cinder.conf"
		DESIGNATE_CONFIG_FILE="/etc/designate/designate.conf"
		GLANCE_API_CONFIG_FILE="/etc/glance/glance-api.conf"
		GLANCE_REGISTRY_CONFIG_FILE="/etc/glance/glance-registry.conf"
		HEAT_CONFIG_FILE="/etc/heat/heat.conf"
		KEYSTONE_CONFIG_FILE="/etc/keystone/keystone.conf"
		MANILA_CONFIG_FILE="/etc/manila/manila.conf"
		MURANO_CONFIG_FILE="/etc/murano/murano.conf"
		NEUTRON_CONFIG_FILE="/etc/neutron/neutron.conf"
		NOVA_CONFIG_FILE="/etc/nova/nova.conf"
		HERE
	fi
}

function __set_config_variables()
{
	if [[ -f ./os-deploy.config ]]; then

		source ./os-deploy.config

		management_nic=${MANAGEMENT_NIC:-"eth0"}
		vxlan_nic=${VXLAN_NIC:-"eth1"}
		ext_nic=${EXT_NIC:-"eth2"}
		vlan_nic=${VLAN_NIC:-"eth3"}

		networking=${NETWORKING}
		proxy=${PROXY}

		vxlan_network=${VXLAN_NETWORK:-127.0.0.1}
		vlan_network=${VLAN_NETWORK:-127.0.0.1}

		# api_address=${API_ADDRESS:-127.0.0.1}
		# my_ip=${MY_IP:-127.0.0.1}
		# hostname=${HOSTNAME:-localhost}
		api_address=${API_ADDRESS:-127.0.0.1}
		my_ip=$(hostname --ip-address)
		hostname=$(hostname)

		tls=${TLS:-false}
		protocol=${PROTOCOL:-http}

		admin_token=${ADMIN_TOKEN:-UNDEFINED}
		metering_secret=${METERING_SECRET:-UNDEFINED}
		metadata_proxy_shared_secret=${METADATA_PROXY_SHARED_SECRET:-JsbKCjKpysqW8WyBnvh2hmEnDCCa3c4v3WfKejBMLhdcDfVZbt}

		cinder_iscsi_drive=${CINDER_ISCSI_DRIVE:-/dev/sdb}
		cinder_iscsi_partition=${CINDER_ISCSI_PARTITION:-/dev/sdb1}
		manila_iscsi_drive=${MANILA_ISCSI_DRIVE:-/dev/sdc}
		manila_iscsi_partition=${MANILA_ISCSI_PARTITION:-/dev/sdc1}

		mysql_aodh_password=${MYSQL_AODH_PASSWORD:-password}
		mysql_cinder_password=${MYSQL_CINDER_PASSWORD:-password}
		mysql_designate_password=${MYSQL_DESIGNATE_PASSWORD:-password}
		mysql_glance_password=${MYSQL_GLANCE_PASSWORD:-password}
		mysql_heat_password=${MYSQL_HEAT_PASSWORD:-password}
		mysql_keystone_password=${MYSQL_KEYSTONE_PASSWORD:-password}
		mysql_manila_password=${MYSQL_MANILA_PASSWORD:-password}
		mysql_murano_password=${MYSQL_MURANO_PASSWORD:-password}
		mysql_neutron_password=${MYSQL_NEUTRON_PASSWORD:-password}
		mysql_nova_password=${MYSQL_NOVA_PASSWORD:-password}
		mysql_root_password=${MYSQL_ROOT_PASSWORD:-password}

		mongod_ceilometer_password=${MONGOD_CEILOMETER_PASSWORD:-password}

		keystone_admin_password=${KEYSTONE_ADMIN_PASSWORD:-password}
		keystone_aodh_password=${KEYSTONE_AODH_PASSWORD:-password}
		keystone_ceilometer_password=${KEYSTONE_CEILOMETER_PASSWORD:-password}
		keystone_cinder_password=${KEYSTONE_CINDER_PASSWORD:-password}
		keystone_designate_password=${KEYSTONE_DESIGNATE_PASSWORD:-password}
		keystone_glance_password=${KEYSTONE_GLANCE_PASSWORD:-password}
		keystone_heat_password=${KEYSTONE_HEAT_PASSWORD:-password}
		keystone_heat_domain_admin_password=${KEYSTONE_HEAT_DOMAIN_ADMIN_PASSWORD:-password}
		keystone_manila_password=${KEYSTONE_MANILA_PASSWORD:-password}
		keystone_murano_password=${KEYSTONE_MURANO_PASSWORD:-password}
		keystone_neutron_password=${KEYSTONE_NEUTRON_PASSWORD:-password}
		keystone_nova_password=${KEYSTONE_NOVA_PASSWORD:-password}

		rabbitmq_host=${api_address}
		rabbitmq_userid=${RABBITMQ_USERID:-openstack}
		rabbitmq_password=${RABBITMQ_PASSWORD:-password}

		ntp_servers=( "${NTP_SERVERS[@]}" )

		dhcp_domain_name=${DHCP_DOMAIN_NAME:-sandbox.sc9b}

		aodh_config_file=${AODH_CONFIG_FILE:-"/etc/aodh/aodh.conf"}
		ceilometer_config_file=${CEILOMETER_CONFIG_FILE:-"/etc/ceilometer/ceilometer.conf"}
		cinder_config_file=${CINDER_CONFIG_FILE:-"/etc/cinder/cinder.conf"}
		designate_config_file=${DESIGNATE_CONFIG_FILE:-"/etc/designate/designate.conf"}
		glance_api_config_file=${GLANCE_API_CONFIG_FILE:-"/etc/glance/glance-api.conf"}
		glance_registry_config_file=${GLANCE_REGISTRY_CONFIG_FILE:-"/etc/glance/glance-registry.conf"}
		heat_config_file=${HEAT_CONFIG_FILE:-"/etc/heat/heat.conf"}
		keystone_config_file=${KEYSTONE_CONFIG_FILE:-"/etc/keystone/keystone.conf"}
		manila_config_file=${MANILA_CONFIG_FILE:-"/etc/manila/manila.conf"}
		murano_config_file=${MURANO_CONFIG_FILE:-"/etc/murano/murano.conf"}
		neutron_config_file=${NEUTRON_CONFIG_FILE:-"/etc/neutron/neutron.conf"}
		nova_config_file=${NOVA_CONFIG_FILE:-"/etc/nova/nova.conf"}

	else
		echo "The configuration file is missing: ./os-deploy.config"
		exit 1
	fi
}

function __print_config()
{
	__set_config_variables

	cat <<-HERE
	MANAGEMENT_NIC  = "${management_nic}"
	VXLAN_NIC       = "${vxlan_nic}"
	EXT_NIC         = "${ext_nic}"
	VLAN_NIC        = "${vlan_nic}"

	NETWORKING      = "${networking}"
	PROXY			= "${proxy}"

	VXLAN_NETWORK   = "${vxlan_network}"
	VLAN_NETWORK    = "${vlan_network}"

	API_ADDRESS     = "${api_address}"
	MY_IP           = "${my_ip}"
	HOSTNAME        = "${hostname}"

	TLS                             = "${tls}""
	PROTOCOL                        = "${protocol}"

	ADMIN_TOKEN                     = "${admin_token}"
	METERING_SECRET                 = "${metering_secret}"
	METADATA_PROXY_SHARED_SECRET    = "${metadata_proxy_shared_secret}"

	CINDER_ISCSI_DRIVE              = "${cinder_iscsi_drive}"
	CINDER_ISCSI_PARTITION          = "${cinder_iscsi_partition}"
	MANILA_ISCSI_DRIVE              = "${manila_iscsi_drive}"
	MANILA_ISCSI_PARTITION          = "${manila_iscsi_partition}"

	MYSQL_AODH_PASSWORD             = "${mysql_aodh_password}"
	MYSQL_CINDER_PASSWORD           = "${mysql_cinder_password}"
	MYSQL_DESIGNATE_PASSWORD        = "${mysql_designate_password}"
	MYSQL_GLANCE_PASSWORD           = "${mysql_glance_password}"
	MYSQL_HEAT_PASSWORD             = "${mysql_heat_password}"
	MYSQL_KEYSTONE_PASSWORD         = "${mysql_keystone_password}"
	MYSQL_MANILA_PASSWORD           = "${mysql_manila_password}"
	MYSQL_MURANO_PASSWORD           = "${mysql_murano_password}"
	MYSQL_NEUTRON_PASSWORD          = "${mysql_neutron_password}"
	MYSQL_NOVA_PASSWORD             = "${mysql_nova_password}"
	MYSQL_ROOT_PASSWORD             = "${mysql_root_password}"

	MONGOD_CEILOMETER_PASSWORD      = "${mongod_ceilometer_password}"

	KEYSTONE_ADMIN_PASSWORD             = "${keystone_admin_password}"
	KEYSTONE_AODH_PASSWORD              = "${keystone_aodh_password}"
	KEYSTONE_CEILOMETER_PASSWORD        = "${keystone_ceilometer_password}"
	KEYSTONE_CINDER_PASSWORD            = "${keystone_cinder_password}"
	KEYSTONE_DESIGNATE_PASSWORD         = "${keystone_designate_password}"
	KEYSTONE_GLANCE_PASSWORD            = "${keystone_glance_password}"
	KEYSTONE_HEAT_PASSWORD              = "${keystone_heat_password}"
	KEYSTONE_HEAT_DOMAIN_ADMIN_PASSWORD = "${keystone_heat_domain_admin_password}"
	KEYSTONE_MANILA_PASSWORD            = "${keystone_manila_password}"
	KEYSTONE_MURANO_PASSWORD            = "${keystone_murano_password}"
	KEYSTONE_NEUTRON_PASSWORD           = "${keystone_neutron_password}"
	KEYSTONE_NOVA_PASSWORD              = "${keystone_nova_password}"

	RABBITMQ_HOST       = "${rabbitmq_host}"
	RABBITMQ_USERID     = "${rabbitmq_userid}"
	RABBITMQ_PASSWORD   = "${rabbitmq_password}"

	NTP_SERVERS         = $(for ntp_server in "${ntp_servers[@]}"; do echo ${ntp_server}; done)

	DHCP_DOMAIN_NAME    = "${dhcp_domain_name}"

	AODH_CONFIG_FILE            = "${aodh_config_file}"
	CEILOMETER_CONFIG_FILE      = "${ceilometer_config_file}"
	CINDER_CONFIG_FILE          = "${cinder_config_file}"
	DESIGNATE_CONFIG_FILE       = "${designate_config_file}"
	GLANCE_API_CONFIG_FILE      = "${glance_api_config_file}"
	GLANCE_REGISTRY_CONFIG_FILE = "${glance_registry_config_file}"
	HEAT_CONFIG_FILE            = "${heat_config_file}"
	KEYSTONE_CONFIG_FILE        = "${keystone_config_file}"
	MANILA_CONFIG_FILE          = "${manila_config_file}"
	MURANO_CONFIG_FILE          = "${murano_config_file}"
	NEUTRON_CONFIG_FILE         = "${neutron_config_file}"
	NOVA_CONFIG_FILE            = "${nova_config_file}"
	HERE

	exit 1
}

function configure_environment()
{
	print "Configuring Environment"

	( grep 'export PS1' /root/.bashrc || ( echo "export PS1='\[\033[01;31m\]\h\[\033[01;34m\] \W \\$\[\033[00m\] '" >> /root/.bashrc ) )  > /dev/null 2>&1

	# /etc/profile
	# export http_proxy=http://10.199.103.207:3128/
	# export https_proxy=http://10.199.103.207:3128/
	# export no_proxy='127.0.0.1,sandbox01,10.199.0.0/16'

	( rpm -q crudini htop || yum -y -q install crudini ) > /dev/null
	( rpm -q htop || yum -y -q install --enablerepo=epel htop ) > /dev/null

	cat <<-HERE> /etc/sysctl.d/ip_forward.conf
	net.ipv4.ip_forward=1
	net.ipv4.conf.all.rp_filter=0
	net.ipv4.conf.default.rp_filter=0
	HERE

	sysctl --system > /dev/null

	print -s "DONE"
}

function configure_limits()
{
	cat <<-HERE > /etc/security/limits.d/root.conf
	root            soft    nofile         8192
	root            hard    nofile         8192
	HERE
}

function configure_repos()
{
    print "Configuring yum repos"

	yum clean all > /dev/null 2>&1

	egrep 'ip_resolve|proxy' /etc/yum.conf > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		sed -i "/\[main\]/ a\# proxy=${proxy}" /etc/yum.conf
		sed -i "/\[main\]/ a\# ip_resolve=4" /etc/yum.conf
	fi

	rpm -q rdo-release-mitaka > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		( yum -y -q install https://repos.fedorapeople.org/repos/openstack/openstack-mitaka/rdo-release-mitaka-5.noarch.rpm  ) > /dev/null
	fi

	rpm -q epel-release > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		( yum -y -q install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm ) > /dev/null
	fi
	sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/epel*

	rpm -q elrepo-release > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		( yum -y -q install http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm ) > /dev/null
	fi

    print -s "DONE"

    print "Installing OpenStack Client"

	( rpm -q yum-plugin-priorities || yum -y -q install yum-plugin-priorities ) > /dev/null

	( rpm -q python-openstackclient || yum -y -q install python-openstackclient ) > /dev/null

	( rpm -q openstack-utils || yum -y -q install openstack-utils ) > /dev/null

    print -s "DONE"
}

function configure_date()
{
	print "Configuring Time Server"

	local ntp_server
	local management_network=$(hostname -i | cut -d'.' -f1-3)

	( rpm -q chrony || yum -y -q install chrony ) > /dev/null

	egrep "^allow ${management_network}.0/24" /etc/chrony.conf > /dev/null 2>&1
	if [[ $? != 0 ]]; then
		sed -i '/^server/d' /etc/chrony.conf
		sed -i '/^allow/d' /etc/chrony.conf
		echo "allow ${management_network}.0/24" >> /etc/chrony.conf
	fi

	for ntp_server in "${ntp_servers[@]}"
	do
		grep "server ${ntp_server} iburst" /etc/chrony.conf > /dev/null 2>&1
		if [[ $? != 0 ]]; then
			echo "server ${ntp_server} iburst" >> /etc/chrony.conf
		fi
	done

	systemctl is-enabled chronyd > /dev/null 2>&1 || systemctl enable chronyd
	systemctl is-active chronyd > /dev/null 2>&1 || ( systemctl restart chronyd && sleep 5 )

	print -s "DONE"
}



