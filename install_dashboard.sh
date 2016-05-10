function install_dashboard()
{
    print "Installing OpenStack Dashboard"

    ( rpm -q openstack-dashboard || yum -y install openstack-dashboard ) > /dev/null

    sed -i 's/^WSGIScriptAlias \/dashboard/WSGIScriptAlias \//' /etc/httpd/conf.d/openstack-dashboard.conf
    sed -i 's/^Alias \/dashboard\/static/Alias \/static/' /etc/httpd/conf.d/openstack-dashboard.conf

    cat <<-HERE > /usr/share/openstack-dashboard/openstack_dashboard/local/local_settings.d/_99_override_all_configuration.py
    WEBROOT = '/'

    OPENSTACK_API_VERSIONS = {
        "data-processing": 1.1,
        "identity": 3,
        "volume": 2,
        "compute": 2,
    }

    ALLOWED_HOSTS = ['10.199.51.11', ]

    OPENSTACK_HOST = "127.0.0.1"
    OPENSTACK_KEYSTONE_URL = "http://%s:5000/v3" % OPENSTACK_HOST

    SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
            'LOCATION': '127.0.0.1:11211',
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

    chown -R apache.apache /usr/share/openstack-dashboard/static

    __enable_service httpd
    __enable_service memcached

    # __start_service httpd
    # __start_service memcached

    __restart_service httpd
    __restart_service memcached

    print -s "DONE"
}function install_glance()
{
    print "Installing Glance"

    ( rpm -q openstack-glance || yum -y -q install openstack-glance python-glance python-glanceclient ) > /dev/null

    __configure_keystone ${glance_api_config_file} glance ${keystone_glance_password}
    __configure_keystone ${glance_registry_config_file} glance ${keystone_glance_password}

    openstack-config --set ${glance_api_config_file} DEFAULT verbose False
    openstack-config --set ${glance_api_config_file} DEFAULT show_image_direct_url True

    openstack-config --set ${glance_api_config_file} database connection mysql+pymysql://glance:${mysql_glance_password}@127.0.0.1/glance

    openstack-config --set ${glance_api_config_file} paste_deploy flavor keystone

    openstack-config --set ${glance_registry_config_file} DEFAULT verbose False

    openstack-config --set ${glance_registry_config_file} database connection mysql+pymysql://glance:${mysql_glance_password}@127.0.0.1/glance

    openstack-config --set ${glance_registry_config_file} paste_deploy flavor keystone

    if [[ ! -f /var/lib/glance/db_sync.lock ]]; then
        ( su -s /bin/sh -c "glance-manage db_sync" glance && touch /var/lib/glance/db_sync.lock
        glance-manage db_load_metadefs ) > /dev/null 2>&1
    fi

    __enable_service openstack-glance-api
    __enable_service openstack-glance-registry

    __start_service openstack-glance-api
    __start_service openstack-glance-registry

    ( echo "export OS_IMAGE_API_VERSION=2" | tee -a /root/admin-openrc.sh ) > /dev/null

    print -s "DONE"
}