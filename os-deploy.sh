#!/bin/bash

# Import system functions
source ./lib/system.sh

# Import OpenStack functions
source ./lib/openstack.sh

####  Usage  ##################################################################

function print_usage()
{
	cat <<-HERE

	Usage:
		$(basename "$0") --networking=[L2|L3]|-n
				 --[compute|controller|allinone]
				 --generate-config|-g
				 --print-config|-p

	Commands:
		-n=*|--networking=*  : Configures OpenStack Networking. L2 or L3
		-g|--generate-config : Generates new configuration file
		-p|--print-config    : Prints running configuration
		--controller         : Configures OpenStack Controller node
		--compute            : Configures OpenStack Compute node
		--allinone           : Configures all-in-one OpenStack IaaS

	HERE
	exit 1
}

if [[ $# -eq 0 ]]; then
	print_usage
fi

####  Roles and Profiles  #####################################################

function deploy_orchestration_controller_bundle()
{
	source ./install_mongodb.sh
	source ./install_ceilometer.sh
	source ./install_aodh.sh
	source ./install_heat.sh

	install_mongodb
	install_ceilometer_api
	install_aodh
	install_heat
}

function deploy_orchestration_compute_bundle()
{
	source ./install_ceilometer.sh

	install_ceilometer_compute
}

function deploy_designate_bundle()
{
	source ./install_designate.sh

	__install_bind
	install_designate
}

function deploy_designate_bundle()
{
	source ./install_designate.sh

	__install_bind
	install_designate
}

function deploy_controller_bundle()
{
	source ./install_mariadb.sh
	source ./install_rabbitmq.sh
	source ./install_memcache.sh
	source ./install_keystone.sh
	source ./install_glance.sh
	source ./install_nova.sh
	source ./install_l2_networking.sh
	source ./install_l3_networking.sh
	source ./install_neutron.sh
	source ./install_dashboard.sh
	source ./install_cinder.sh
	source ./install_cinder_api.sh
	source ./install_cinder_storage_lvm.sh
	source ./install_haproxy.sh

	__set_config_variables
	configure_repos
	configure_environment
	configure_date
	configure_limits
	install_mysql
	install_rabbitmq
	install_memcache
	install_keystone
	configure_endpoints
	install_glance
	install_nova_api
	install_neutron_api ${networking}
	install_dashboard
	install_cinder
	configure_cinder_api
	# configure_cinder_storage
	if [[ ${ORCHESTRATION} ]]; then
		deploy_orchestration_controller_bundle
	fi
	install_haproxy
	__finish_installation
}

function deploy_compute_bundle()
{
	source ./install_nova.sh
	source ./install_l2_networking.sh
	source ./install_l3_networking.sh
	source ./install_neutron.sh
	source ./install_cinder.sh
	source ./install_cinder_storage_lvm.sh

	__set_config_variables
	configure_repos
	configure_environment
	configure_date
	configure_limits
	install_nova_compute
	install_neutron_compute ${networking}
	# install_cinder
	# configure_cinder_storage
	if [[ ${ORCHESTRATION} ]]; then
		deploy_orchestration_compute_bundle
	fi
	__cleanup_systemd_permissions
}

function deploy_cinder_bundle()
{
	source ./install_cinder.sh
	source ./install_cinder_api.sh
	source ./install_cinder_storage_lvm.sh

	__set_config_variables
	configure_repos
	configure_environment
	configure_date
	configure_limits
	install_cinder
	configure_cinder_storage
	__cleanup_systemd_permissions
}

function deploy_allinone_bundle()
{
	source ./install_mariadb.sh
	source ./install_rabbitmq.sh
	source ./install_memcache.sh
	source ./install_keystone.sh
	source ./install_glance.sh
	source ./install_nova.sh
	source ./install_l2_networking.sh
	source ./install_l3_networking.sh
	source ./install_neutron.sh
	source ./install_dashboard.sh
	source ./install_cinder.sh
	source ./install_cinder_api.sh
	source ./install_cinder_storage_lvm.sh
	# source ./install_manila_storage_nfs.sh
	# source ./install_manila_api.sh
	# source ./install_murano.sh

	__set_config_variables
	configure_repos
	configure_environment
	configure_date
	configure_limits
	install_mysql
	install_rabbitmq
	install_memcache
	install_keystone
	configure_endpoints
	install_glance
	install_nova_api
	install_nova_compute
	install_neutron_compute ${networking}
	install_neutron_api ${networking}
	install_dashboard
	install_cinder
	configure_cinder_api
	configure_cinder_storage
	__finish_installation
}

####  main()  #################################################################

ROLE=""
NETWORKING=""
ORCHESTRATION=false
DESIGNATE=false
MANILA=false
MURANO=false
TLS=false
PROTOCOL='http'
PROXY=""

for i in "$@"
do
case $i in
	-n=*|--networking=*)
		NETWORKING="${i#*=}"
		shift
		;;
	--proxy=*)
		PROXY="${i#*=}"
		shift
		;;
	-g|--generate-config)
		__generate_config_file
		shift
		;;
	-p|--print-config)
		__print_config
		shift
		;;
	--add-orchestration)
		ORCHESTRATION=true
		shift
		;;
	--add-designate)
		DESIGNATE=true
		shift
		;;
	--add-manila)
		MANILA=true
		shift
		;;
	--add-murano)
		MURANO=true
		shift
		;;
	--add-designate)
		DESIGNATE=true
		shift
		;;
	--tls)
		TLS=true
		PROTOCOL='https'
		shift
		;;
	--controller)
		__verify_role ${i:2}
		deploy_controller_bundle
		shift
		;;
	--compute)
		__verify_role ${i:2}
		deploy_compute_bundle
		shift
		;;
	--cinder)
		__verify_role ${i:2}
		deploy_cinder_bundle
		shift
		;;
	--allinone)
		__verify_role ${i:2}
		deploy_allinone_bundle
		shift
		;;
	*)
		print_usage
	;;
esac
done
