function __install_murano_dashboard()
{
    cd /images/

    git clone -b stable/mitaka https://github.com/openstack/murano-dashboard.git
    cd /images/murano-dashboard

    python setup.py sdist
    pip install dist/*.tar.gz

    cp ./muranodashboard/local/_50_murano.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/

    __restart_service httpd
    __restart_service memcached
}

function install_murano()
{
    print "Installing Murano API"

    ( rpm -q openstack-murano-api openstack-murano-cf-api openstack-murano-common openstack-murano-engine || yum -y install openstack-murano-api openstack-murano-cf-api openstack-murano-common openstack-murano-engine ) > /dev/null

    __configure_keystone ${murano_config_file} murano ${keystone_murano_password}

    __configure_oslo_messaging_rabbit ${murano_config_file}

    openstack-config --set ${murano_config_file} DEFAULT verbose True
    openstack-config --set ${murano_config_file} DEFAULT debug False
    openstack-config --set ${murano_config_file} DEFAULT rpc_backend rabbit

    openstack-config --set ${murano_config_file} database connection mysql+pymysql://murano:${mysql_murano_password}@127.0.0.1/murano

    openstack-config --set ${murano_config_file} murano url http://${api_address}:8082

    openstack-config --set ${murano_config_file} keystone_authtoken auth_uri http://sandbox01:5000
    openstack-config --set ${murano_config_file} keystone_authtoken auth_host ${api_address}
    openstack-config --set ${murano_config_file} keystone_authtoken auth_port 5000
    openstack-config --set ${murano_config_file} keystone_authtoken auth_protocol http
    openstack-config --set ${murano_config_file} keystone_authtoken admin_tenant_name service
    openstack-config --set ${murano_config_file} keystone_authtoken admin_user murano
    openstack-config --set ${murano_config_file} keystone_authtoken admin_password ${keystone_murano_password}

    openstack-config --set ${murano_config_file} networking default_dns 10.199.51.5

    openstack-config --set ${murano_config_file} oslo_concurrency lock_path /var/lib/murano/tmp

    openstack-config --set ${murano_config_file} oslo_messaging_notifications driver messagingv2

    openstack-config --set ${murano_config_file} rabbitmq host ${rabbitmq_host}
    openstack-config --set ${murano_config_file} rabbitmq login ${rabbitmq_userid}
    openstack-config --set ${murano_config_file} rabbitmq password ${rabbitmq_password}
    openstack-config --set ${murano_config_file} rabbitmq virtual_host /

    mkdir -p /var/lib/murano/tmp
    chown murano.murano /var/lib/murano/tmp
    chmod 700 /var/lib/murano/tmp

    ( su -s /bin/sh -c "murano-db-manage --config-file /etc/murano/murano.conf upgrade" murano ) > /dev/null 2>&1

    export OS_PROJECT_DOMAIN_ID=fed0c965615441f2a6cb4f76b73a4ac9 | tee -a admin-openrc.sh
    export OS_USER_DOMAIN_ID=fed0c965615441f2a6cb4f76b73a4ac9 | tee -a admin-openrc.sh

    murano --murano-repo-url="http://storage.apps.openstack.org/" package-import io.murano.apps.apache.ApacheHttpServer
    murano --murano-repo-url="http://storage.apps.openstack.org/" package-import io.murano.databases.MySql
    murano package-import io.murano.zip

    zip -r myfiles.zip myfiles

}
