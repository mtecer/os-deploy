function configure_cinder_api()
{
	print "Configuring Cinder API"

	( su -s /bin/sh -c "cinder-manage db sync" cinder ) > /dev/null 2>&1

	__enable_service openstack-cinder-api
	__enable_service openstack-cinder-scheduler
	# systemctl enable openstack-cinder-backup

	__start_service openstack-cinder-api
	__start_service openstack-cinder-scheduler
	# systemctl restart openstack-cinder-backup

	( echo "export OS_VOLUME_API_VERSION=2" | tee -a /root/admin-openrc.sh ) > /dev/null

	print -s "DONE"
}
