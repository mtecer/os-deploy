function install_aodh()
{
	print "Installing Aodh"

	( rpm -q openstack-aodh-api openstack-aodh-evaluator openstack-aodh-notifier openstack-aodh-listener openstack-aodh-expirer || yum -y install openstack-aodh-api openstack-aodh-evaluator openstack-aodh-notifier openstack-aodh-listener openstack-aodh-expirer python-ceilometerclient ) > /dev/null

	__configure_keystone ${aodh_config_file} aodh ${keystone_aodh_password}

	__configure_service_credentials ${aodh_config_file} aodh ${keystone_aodh_password}

	__configure_oslo_messaging_rabbit ${aodh_config_file}

	openstack-config --set ${aodh_config_file} DEFAULT auth_strategy keystone
	openstack-config --set ${aodh_config_file} DEFAULT rpc_backend rabbit

	openstack-config --set ${aodh_config_file} database connection mysql+pymysql://aodh:mysql_aodh_password@${api_address}/aodh

	( su -s /bin/sh -c "aodh-dbsync" aodh ) > /dev/null 2>&1

	__enable_service openstack-aodh-api
	__enable_service openstack-aodh-evaluator
	__enable_service openstack-aodh-notifier
	__enable_service openstack-aodh-listener

	__start_service openstack-aodh-api
	__start_service openstack-aodh-evaluator
	__start_service openstack-aodh-notifier
	__start_service openstack-aodh-listener

	print -s "DONE"
}
