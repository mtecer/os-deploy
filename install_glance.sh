function install_glance()
{
	print "Installing Glance"

	( rpm -q openstack-glance || yum -y -q install openstack-glance python-glance python-glanceclient ) > /dev/null

	__configure_keystone ${glance_api_config_file} glance ${keystone_glance_password}
	__configure_keystone ${glance_registry_config_file} glance ${keystone_glance_password}

	openstack-config --set ${glance_api_config_file} DEFAULT verbose False
	openstack-config --set ${glance_api_config_file} DEFAULT show_image_direct_url True

	openstack-config --set ${glance_api_config_file} database connection mysql+pymysql://glance:${mysql_glance_password}@${api_address}/glance

	openstack-config --set ${glance_api_config_file} paste_deploy flavor keystone

	openstack-config --set ${glance_registry_config_file} DEFAULT verbose False

	openstack-config --set ${glance_registry_config_file} database connection mysql+pymysql://glance:${mysql_glance_password}@${api_address}/glance

	openstack-config --set ${glance_registry_config_file} paste_deploy flavor keystone

	if [[ ! -f /var/lib/glance/db_sync.lock ]]; then
		( su -s /bin/sh -c "glance-manage db_sync" glance && touch /var/lib/glance/db_sync.lock
		glance-manage db_load_metadefs ) > /dev/null 2>&1
	fi

	__enable_service openstack-glance-api
	__enable_service openstack-glance-registry

	__start_service openstack-glance-api
	__start_service openstack-glance-registry

	print -s "DONE"
}