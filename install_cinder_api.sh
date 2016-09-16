function configure_cinder_api()
{
	print "Configuring Cinder API"

    openstack-config --set ${cinder_config_file} DEFAULT osapi_volume_listen 127.0.0.1

    if [[ ${cinder_default_volume_type} ]]; then
        openstack-config --set ${cinder_config_file} DEFAULT default_volume_type ${cinder_default_volume_type}
    else
        openstack-config --del ${cinder_config_file} DEFAULT default_volume_type
    fi

	( su -s /bin/sh -c "cinder-manage db sync" cinder ) > /dev/null 2>&1

	__enable_service openstack-cinder-api
	__enable_service openstack-cinder-scheduler
	# systemctl enable openstack-cinder-backup

	__start_service openstack-cinder-api
	__start_service openstack-cinder-scheduler
	# systemctl restart openstack-cinder-backup

	# ( echo "export OS_VOLUME_API_VERSION=2" | tee -a /root/admin-openrc.sh ) > /dev/null

	print -s "DONE"
}
