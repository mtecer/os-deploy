function configure_cinder_storage()
{
	print "Configuring Cinder iSCSI Storage"

	__generate_openrc

	__hostname=$(hostname -s)
	__storage_name=$(hostname -s)

	( rpm -q targetcli || yum -y install lvm2 targetcli ) > /dev/null

	( grep 'filter = \[ "a\/sda\/", "a\/sdb\/", "r\/.\*\/" ]' /etc/lvm/lvm.conf ) > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		sed -i '/devices {/ a\\tfilter = [ "a/sda/", "a/sdb/", "r/.*/" ]' /etc/lvm/lvm.conf
	fi

	( vgdisplay cinder-volumes ) > /dev/null 2>&1
	if [[ $? != 0 ]]; then
		if [[ -b ${cinder_iscsi_partition} ]]; then
			( pvcreate ${cinder_iscsi_partition}
			vgcreate cinder-volumes ${cinder_iscsi_partition} ) > /dev/null 2>&1
		else
			( parted -s ${cinder_iscsi_drive} mklabel gpt
			parted -s -a optimal ${cinder_iscsi_drive} mkpart primary 0% 100%
			pvcreate ${cinder_iscsi_partition}
			vgcreate cinder-volumes ${cinder_iscsi_partition} ) > /dev/null 2>&1
		fi
	fi

	__enable_service lvm2-lvmetad
	__enable_service target

	__start_service lvm2-lvmetad
	__start_service target

	# openstack-config --set ${cinder_config_file} DEFAULT storage_availability_zone "${__storage_name}"
	# openstack-config --set ${cinder_config_file} DEFAULT enabled_backends "${__storage_name}"

	openstack-config --set ${cinder_config_file} DEFAULT storage_availability_zone nova
	openstack-config --set ${cinder_config_file} DEFAULT enabled_backends "${__storage_name}"

	openstack-config --set ${cinder_config_file} ${__storage_name} iscsi_helper lioadm
	openstack-config --set ${cinder_config_file} ${__storage_name} iscsi_protocol iscsi
	openstack-config --set ${cinder_config_file} ${__storage_name} volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
	openstack-config --set ${cinder_config_file} ${__storage_name} iscsi_ip_address ${my_ip}
	openstack-config --set ${cinder_config_file} ${__storage_name} volume_group cinder-volumes
	openstack-config --set ${cinder_config_file} ${__storage_name} volume_backend_name "${__storage_name}"

	( cinder type-create ${__storage_name}
	cinder type-key ${__storage_name} set volume_backend_name=${__storage_name} ) > /dev/null 2>&1

	__enable_service openstack-cinder-volume
	__start_service openstack-cinder-volume

	print -s "DONE"
}
