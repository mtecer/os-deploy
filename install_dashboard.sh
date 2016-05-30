function install_dashboard()
{
	print "Installing OpenStack Dashboard"

	( rpm -q openstack-dashboard || yum -y install openstack-dashboard ) > /dev/null

	sed -i 's/^WSGIScriptAlias \/dashboard/WSGIScriptAlias \//' /etc/httpd/conf.d/openstack-dashboard.conf
	sed -i 's/^Alias \/dashboard\/static/Alias \/static/' /etc/httpd/conf.d/openstack-dashboard.conf

	touch /usr/share/openstack-dashboard/openstack_dashboard/local/local_settings.d/_99_override_all_configuration.py
	_md5sum_original=$(md5sum /usr/share/openstack-dashboard/openstack_dashboard/local/local_settings.d/_99_override_all_configuration.py)

	cat <<-HERE > /usr/share/openstack-dashboard/openstack_dashboard/local/local_settings.d/_99_override_all_configuration.py
	WEBROOT = '/'

	OPENSTACK_API_VERSIONS = {
		"data-processing": 1.1,
		"identity": 3,
		"volume": 2,
		"compute": 2,
	}

	ALLOWED_HOSTS = ['*', ]

	OPENSTACK_HOST = "${api_address}"
	OPENSTACK_KEYSTONE_URL = "http://%s:5000/v3" % OPENSTACK_HOST

	SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
	CACHES = {
		'default': {
			'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
			'LOCATION': "${api_address}",
		}
	}

	SESSION_EXPIRE_AT_BROWSER_CLOSE = True
	SESSION_TIMEOUT = 14400

	OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"
	OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "default"
	OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True

	OPENSTACK_HYPERVISOR_FEATURES = {
		'can_set_mount_point': True,
		'can_set_password': False,
		'requires_keypair': False,
	}

	OPENSTACK_CINDER_FEATURES = {
		'enable_backup': True,
	}

	OPENSTACK_NEUTRON_NETWORK = {
		'enable_router': True,
		'enable_quotas': True,
		'enable_ipv6': True,
		'enable_distributed_router': False,
		'enable_ha_router': False,
		'enable_lb': True,
		'enable_firewall': True,
		'enable_vpn': True,
		'enable_fip_topology_check': True,
	}

	LAUNCH_INSTANCE_LEGACY_ENABLED = False
	LAUNCH_INSTANCE_NG_ENABLED = True

	TIME_ZONE = "UTC"
	HERE

	_md5sum_updated=$(md5sum /usr/share/openstack-dashboard/openstack_dashboard/local/local_settings.d/_99_override_all_configuration.py)

	chown -R apache.apache /usr/share/openstack-dashboard/static

	__enable_service httpd
	__enable_service memcached

	if [[ ${_md5sum_original} != ${_md5sum_updated} ]]; then
		__restart_service httpd
		__restart_service memcached
	fi

	print -s "DONE"
}
