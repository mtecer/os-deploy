function configure_cinder_storage()
{
    print "Installing Cinder iSCSI Storage"

    ( rpm -q targetcli || yum -y install lvm2 targetcli ) > /dev/null

    ( grep 'filter = \[ "a\/sda\/", "a\/sdb\/", "r\/.\*\/" ]' /etc/lvm/lvm.conf ) > /dev/null 2>&1
    if [[ $? == 1 ]]; then
        sed -i '/devices {/ a\\tfilter = [ "a/sda/", "a/sdb/", "r/.*/" ]' /etc/lvm/lvm.conf

        ( parted /dev/${cinder_iscsi_partition} mklabel gpt
        parted -s -a optimal /dev/${cinder_iscsi_partition} mkpart primary 0% 100%

        pvcreate /dev/${cinder_iscsi_partition}1

        vgcreate cinder-volumes /dev/${cinder_iscsi_partition}1 ) > /dev/null
    fi

    __enable_service lvm2-lvmetad
    __enable_service target

    __start_service lvm2-lvmetad
    __start_service target

    openstack-config --set ${cinder_config_file} DEFAULT default_volume_type lvm
    # openstack-config --set ${cinder_config_file} DEFAULT enabled_backends 'LVM'

    openstack-config --set ${cinder_config_file} lvm iscsi_helper lioadm
    openstack-config --set ${cinder_config_file} lvm iscsi_protocol iscsi
    openstack-config --set ${cinder_config_file} lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
    openstack-config --set ${cinder_config_file} lvm iscsi_ip_address 127.0.0.1
    openstack-config --set ${cinder_config_file} lvm volume_group cinder-volumes
    openstack-config --set ${cinder_config_file} lvm volume_backend_name LVM

    ( cinder type-create lvm
    cinder type-key lvm set volume_backend_name=LVM ) > /dev/null 2>&1

    __enable_service openstack-cinder-volume
    __start_service openstack-cinder-volume

    print -s "DONE"
}
