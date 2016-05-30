function configure_cinder_storage()
{
	print "Configuring Cinder iSCSI Storage"

	__generate_openrc

	__storage_name=$(hostname -s)

	( rpm -q targetcli || yum -y install lvm2 targetcli ) > /dev/null

	( grep 'filter = \[ "a\/sda\/", "a\/sdb\/", "r\/.\*\/" ]' /etc/lvm/lvm.conf ) > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		sed -i '/devices {/ a\\tfilter = [ "a/sda/", "a/sdb/", "r/.*/" ]' /etc/lvm/lvm.conf

		( parted /dev/${cinder_iscsi_partition} mklabel gpt
		parted -s -a optimal /dev/${cinder_iscsi_partition} mkpart primary 0% 100%

		pvcreate /dev/${cinder_iscsi_partition}1

		vgcreate cinder-volumes /dev/${cinder_iscsi_partition}1 ) > /dev/null 2>&1
	fi

	__enable_service lvm2-lvmetad
	__enable_service target

	__start_service lvm2-lvmetad
	__start_service target

	openstack-config --set ${cinder_config_file} DEFAULT storage_availability_zone "${__storage_name}"

	openstack-config --set ${cinder_config_file} DEFAULT enabled_backends "${__storage_name}"

	openstack-config --set ${cinder_config_file} ${__storage_name} iscsi_helper lioadm
	openstack-config --set ${cinder_config_file} ${__storage_name} iscsi_protocol iscsi
	openstack-config --set ${cinder_config_file} ${__storage_name} volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
	openstack-config --set ${cinder_config_file} ${__storage_name} iscsi_ip_address ${my_ip}
	openstack-config --set ${cinder_config_file} ${__storage_name} volume_group cinder-volumes
	openstack-config --set ${cinder_config_file} ${__storage_name} volume_backend_name ${__storage_name}

	( cinder type-create ${__storage_name}
	cinder type-key ${__storage_name} set volume_backend_name=${__storage_name} ) > /dev/null 2>&1

	__enable_service openstack-cinder-volume
	__start_service openstack-cinder-volume

	print -s "DONE"
}
