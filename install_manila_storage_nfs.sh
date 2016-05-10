function install_manila_storage_nfs()
{
    print "Installing Manila Storage"

    ( rpm -q openstack-manila-share python2-PyMySQL lvm2 nfs-utils nfs4-acl-tools portmap || yum -y install openstack-manila-share python2-PyMySQL lvm2 nfs-utils nfs4-acl-tools portmap ) > /dev/null

    __configure_keystone ${manila_config_file} manila ${keystone_manila_password}

    __configure_oslo_messaging_rabbit ${manila_config_file}

    openstack-config --set ${manila_config_file} DEFAULT verbose False

    openstack-config --set ${manila_config_file} DEFAULT auth_strategy keystone
    openstack-config --set ${manila_config_file} DEFAULT default_share_type default_share_type
    openstack-config --set ${manila_config_file} DEFAULT my_ip ${my_ip}
    openstack-config --set ${manila_config_file} DEFAULT rootwrap_config /etc/manila/rootwrap.conf
    openstack-config --set ${manila_config_file} DEFAULT rpc_backend rabbit

    openstack-config --set ${manila_config_file} DEFAULT default_log_levels amqp=WARN,amqplib=WARN,boto=WARN,qpid=WARN,sqlalchemy=WARN,suds=INFO,oslo.messaging=INFO,iso8601=WARN,requests.packages.urllib3.connectionpool=WARN,urllib3.connectionpool=WARN,websocket=WARN,requests.packages.urllib3.util.retry=WARN,urllib3.util.retry=WARN,keystonemiddleware=WARN,routes.middleware=WARN,stevedore=WARN,taskflow=WARN,keystoneauth=WARN,oslo.cache=INFO,dogpile.core.dogpile=INFO,manila.context=ERROR

    openstack-config --set ${manila_config_file} database connection mysql+pymysql://manila:${mysql_manila_password}@127.0.0.1/manila

    openstack-config --set ${manila_config_file} oslo_concurrency lock_path /var/lib/manila/tmp

    __enable_service lvm2-lvmetad
    __start_service lvm2-lvmetad

    ( grep 'filter = \[ "a\/sda\/", "a\/sdb\/", "r\/.\*\/" ]' /etc/lvm/lvm.conf ) > /dev/null 2>&1
    if [[ $? == 1 ]]; then
        sed -i '/devices {/ a\\tfilter = [ "a/sda/", "a/sdb/", "r/.*/" ]' /etc/lvm/lvm.conf

        parted /dev/${manila_iscsi_partition} mklabel gpt
        parted -s -a optimal /dev/${manila_iscsi_partition} mkpart primary 0% 100%

        pvcreate /dev/${manila_iscsi_partition}1

        vgcreate manila-volumes /dev/${manila_iscsi_partition}1
    fi

    openstack-config --set ${manila_config_file} DEFAULT default_share_type lvm
    openstack-config --set ${manila_config_file} DEFAULT enabled_share_backends lvm
    openstack-config --set ${manila_config_file} DEFAULT enabled_share_protocols NFS

    openstack-config --set ${manila_config_file} lvm share_backend_name LVM
    openstack-config --set ${manila_config_file} lvm share_driver manila.share.drivers.lvm.LVMShareDriver
    openstack-config --set ${manila_config_file} lvm driver_handles_share_servers False
    openstack-config --set ${manila_config_file} lvm lvm_share_volume_group manila-volumes
    openstack-config --set ${manila_config_file} lvm lvm_share_export_ip ${my_ip}

    __enable_service openstack-manila-share
    __start_service openstack-manila-share

    manila type-create LVM False
    manila type-key LVM set share_backend_name='LVM'
    manila type-list

    manila create --share-type LVM --name test nfs 1
    manila access-allow 7fdda283-3bbe-4a1f-bc8d-10afa5f7e4fa ip 10.199.54.0/24

    # # vim /etc/sysconfig/nfs
    # MOUNTD_PORT=892
    # LOCKD_TCPPORT=32803
    # LOCKD_UDPPORT=32769
    # STATD_PORT=662

    systemctl enable rpcbind
    systemctl enable nfs-kernel-server

    systemctl start rpcbind nfs-server

    systemctl restart nfs-config
    systemctl restart nfs

    print -s "DONE"
}
