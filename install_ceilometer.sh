function install_ceilometer_api()
{
	print "Installing Ceilometer API"

	( rpm -q openstack-ceilometer-api openstack-ceilometer-collector openstack-ceilometer-notification openstack-ceilometer-central || yum -y install openstack-ceilometer-api openstack-ceilometer-collector openstack-ceilometer-notification openstack-ceilometer-central python-ceilometerclient ) > /dev/null

	__configure_keystone ${ceilometer_config_file} ceilometer ${keystone_ceilometer_password}

	__configure_service_credentials ${ceilometer_config_file} ceilometer ${keystone_ceilometer_password}

	__configure_oslo_messaging_rabbit ${ceilometer_config_file}

	openstack-config --set ${ceilometer_config_file} DEFAULT auth_strategy keystone
	openstack-config --set ${ceilometer_config_file} DEFAULT rpc_backend rabbit
    openstack-config --set ${ceilometer_config_file} DEFAULT default_log_levels 'amqp=WARN,amqplib=WARN,boto=WARN,qpid=WARN,sqlalchemy=WARN,suds=WARN,oslo.messaging=WARN,iso8601=WARN,requests.packages.urllib3.connectionpool=WARN,urllib3.connectionpool=WARN,websocket=WARN,requests.packages.urllib3.util.retry=WARN,urllib3.util.retry=WARN,keystonemiddleware=WARN,routes.middleware=WARN,stevedore=WARN,taskflow=WARN,keystoneauth=WARN,oslo.cache=WARN,dogpile.core.dogpile=WARN,ceilometer.agent=WARN,ceilometer.agent.discovery.endpoint=ERROR'

    openstack-config --set ${ceilometer_config_file} api default_api_return_limit 1024
    openstack-config --set ${ceilometer_config_file} api host 127.0.0.1

	openstack-config --set ${ceilometer_config_file} database connection mongodb://ceilometer:${mongod_ceilometer_password}@${mongod_servers}/ceilometer
    openstack-config --set ${ceilometer_config_file} database event_time_to_live 2592000
    openstack-config --set ${ceilometer_config_file} database metering_time_to_live 2592000

	openstack-config --set ${ceilometer_config_file} publisher telemetry_secret $metering_secret

	openstack-config --set ${ceilometer_config_file} service_credentials auth_url ${protocol}://${api_address}:35357
	openstack-config --set ${ceilometer_config_file} service_credentials auth_type password
	openstack-config --set ${ceilometer_config_file} service_credentials project_domain_name default
	openstack-config --set ${ceilometer_config_file} service_credentials user_domain_name default
	openstack-config --set ${ceilometer_config_file} service_credentials project_name service
	openstack-config --set ${ceilometer_config_file} service_credentials username ceilometer
	openstack-config --set ${ceilometer_config_file} service_credentials password ${keystone_ceilometer_password}
	openstack-config --set ${ceilometer_config_file} service_credentials interface internalURL
	openstack-config --set ${ceilometer_config_file} service_credentials region_name RegionOne

	cat lib/ceilometer/pipeline.yaml > /etc/ceilometer/pipeline.yaml

	__enable_service openstack-ceilometer-api
	__enable_service openstack-ceilometer-notification
	__enable_service openstack-ceilometer-central
	__enable_service openstack-ceilometer-collector

	__start_service openstack-ceilometer-api
	__start_service openstack-ceilometer-notification
	__start_service openstack-ceilometer-central
	__start_service openstack-ceilometer-collector

	__configure_oslo_messaging_rabbit ${glance_api_config_file}

	( systemctl is-active openstack-ceilometer-api openstack-ceilometer-notification openstack-ceilometer-central openstack-ceilometer-collector ) > /dev/null  2>&1
	if [[ $? == 0 ]]; then
		openstack-config --set ${glance_api_config_file} DEFAULT rpc_backend rabbit

		openstack-config --set ${glance_api_config_file} oslo_messaging_notifications driver messagingv2

		__restart_service openstack-glance-api
		__restart_service openstack-glance-registry

		openstack-config --set /etc/cinder/cinder.conf oslo_messaging_notifications driver messagingv2

		__restart_service openstack-cinder-api.service
		__restart_service openstack-cinder-scheduler.service
		__restart_service openstack-cinder-volume.service

		openstack-config --set /etc/neutron/neutron.conf oslo_messaging_notifications driver messagingv2

		__restart_service neutron-server
	fi

	print -s "DONE"
}

function install_ceilometer_compute()
{
	print "Installing Ceilometer Compute"

	( rpm -q openstack-ceilometer-compute || yum -y install openstack-ceilometer-compute python-ceilometerclient python-pecan ) > /dev/null

	__configure_keystone ${ceilometer_config_file} ceilometer ${keystone_ceilometer_password}

	__configure_oslo_messaging_rabbit ${ceilometer_config_file}

	openstack-config --set ${ceilometer_config_file} DEFAULT auth_strategy keystone
	openstack-config --set ${ceilometer_config_file} DEFAULT rpc_backend rabbit
    openstack-config --set ${ceilometer_config_file} DEFAULT default_log_levels 'amqp=WARN,amqplib=WARN,boto=WARN,qpid=WARN,sqlalchemy=WARN,suds=WARN,oslo.messaging=WARN,iso8601=WARN,requests.packages.urllib3.connectionpool=WARN,urllib3.connectionpool=WARN,websocket=WARN,requests.packages.urllib3.util.retry=WARN,urllib3.util.retry=WARN,keystonemiddleware=WARN,routes.middleware=WARN,stevedore=WARN,taskflow=WARN,keystoneauth=WARN,oslo.cache=WARN,dogpile.core.dogpile=WARN,ceilometer.agent=WARN'

	openstack-config --set ${ceilometer_config_file} service_credentials auth_url ${protocol}://${api_address}:35357
	openstack-config --set ${ceilometer_config_file} service_credentials auth_type password
	openstack-config --set ${ceilometer_config_file} service_credentials project_domain_name default
	openstack-config --set ${ceilometer_config_file} service_credentials user_domain_name default
	openstack-config --set ${ceilometer_config_file} service_credentials project_name service
	openstack-config --set ${ceilometer_config_file} service_credentials username ceilometer
	openstack-config --set ${ceilometer_config_file} service_credentials password ${keystone_ceilometer_password}
	openstack-config --set ${ceilometer_config_file} service_credentials interface internalURL
	openstack-config --set ${ceilometer_config_file} service_credentials region_name RegionOne

	cat lib/ceilometer/pipeline.yaml > /etc/ceilometer/pipeline.yaml

	openstack-config --set ${nova_config_file} DEFAULT instance_usage_audit True
	openstack-config --set ${nova_config_file} DEFAULT instance_usage_audit_period hour
	openstack-config --set ${nova_config_file} DEFAULT notify_on_state_change vm_and_task_state
	openstack-config --set ${nova_config_file} DEFAULT notification_driver messagingv2

	__enable_service openstack-ceilometer-compute
	__start_service openstack-ceilometer-compute

	__restart_service openstack-nova-compute

	print -s "DONE"
}