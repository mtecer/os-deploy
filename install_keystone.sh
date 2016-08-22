function configure_endpoints()
{
	print -n "Creating OpenStack Services and Users"

	unset ADMIN_TOKEN
	export OS_TOKEN=${admin_token}
	export OS_URL=${protocol}://${api_address}:35357/v3
	export OS_IDENTITY_API_VERSION=3

	print -n "\tKeystone"

	openstack service show keystone > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		( openstack service create --name keystone --description "OpenStack Identity" identity

		openstack endpoint create --region RegionOne identity public ${protocol}://${api_address}:5000/v3
		openstack endpoint create --region RegionOne identity internal ${protocol}://${api_address}:5000/v3
		openstack endpoint create --region RegionOne identity admin ${protocol}://${api_address}:35357/v3

		openstack domain create --description "Default Domain" default

		openstack project create --domain default --description "Admin Project" admin
		openstack project create --domain default --description "Service Project" service

		openstack user create --domain default admin --password ${keystone_admin_password}
		openstack role create admin
		openstack role add --project admin --user admin admin ) > /dev/null 2>&1
	fi

	unset OS_TOKEN OS_URL

	# vim /etc/keystone/keystone-paste.ini
	# OR vim /usr/share/keystone/keystone-dist-paste.ini
	# remove admin_token_auth from [pipeline:public_api],[pipeline:admin_api],[pipeline:api_v3]

	__generate_openrc

	print -n "\tGlance"

	openstack service show glance > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		( openstack service create --name glance --description "OpenStack Image Service" image
		openstack user create --domain default --password ${keystone_glance_password} glance
		openstack role add --project service --user glance admin

		openstack endpoint create --region RegionOne image public http://${api_address}:9292
		openstack endpoint create --region RegionOne image internal http://${api_address}:9292
		openstack endpoint create --region RegionOne image admin http://${api_address}:9292 ) > /dev/null 2>&1
	fi

	print -n "\tNova"

	openstack service show nova > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		( openstack service create --name nova --description "OpenStack Compute" compute
		openstack user create --domain default --password ${keystone_nova_password} nova
		openstack role add --project service --user nova admin

		openstack endpoint create --region RegionOne compute public http://${api_address}:8774/v2.1/%\(tenant_id\)s
		openstack endpoint create --region RegionOne compute internal http://${api_address}:8774/v2.1/%\(tenant_id\)s
		openstack endpoint create --region RegionOne compute admin http://${api_address}:8774/v2.1/%\(tenant_id\)s  ) > /dev/null 2>&1
	fi

	print -n "\tNeutron"

	openstack service show neutron > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		( openstack service create --name neutron --description "OpenStack Networking" network
		openstack user create --domain default --password ${keystone_neutron_password} neutron
		openstack role add --project service --user neutron admin

		openstack endpoint create --region RegionOne network public http://${api_address}:9696
		openstack endpoint create --region RegionOne network internal http://${api_address}:9696
		openstack endpoint create --region RegionOne network admin http://${api_address}:9696 ) > /dev/null 2>&1
	fi

	print -n "\tCinder"

	(openstack service show cinder && openstack service show cinderv2) > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		( openstack service create --name cinder --description "OpenStack Block Storage" volume
		openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
		openstack user create --domain default --password ${keystone_cinder_password} cinder
		openstack role add --project service --user cinder admin

		openstack endpoint create --region RegionOne volume public http://${api_address}:8776/v1/%\(tenant_id\)s
		openstack endpoint create --region RegionOne volume internal http://${api_address}:8776/v1/%\(tenant_id\)s
		openstack endpoint create --region RegionOne volume admin http://${api_address}:8776/v1/%\(tenant_id\)s

		openstack endpoint create --region RegionOne volumev2 public http://${api_address}:8776/v2/%\(tenant_id\)s
		openstack endpoint create --region RegionOne volumev2 internal http://${api_address}:8776/v2/%\(tenant_id\)s
		openstack endpoint create --region RegionOne volumev2 admin http://${api_address}:8776/v2/%\(tenant_id\)s ) > /dev/null 2>&1
	fi

	if [[ "${ORCHESTRATION}" == true ]]; then
		print -n "\tCeilometer"

		openstack service show ceilometer > /dev/null 2>&1
		if [[ $? == 1 ]]; then
			( openstack service create --name ceilometer --description "OpenStack Telemetry" metering
			openstack user create --domain default --password ${keystone_ceilometer_password} ceilometer
			openstack role add --project service --user ceilometer admin

			openstack endpoint create --region RegionOne metering public http://${api_address}:8777
			openstack endpoint create --region RegionOne metering internal http://${api_address}:8777
			openstack endpoint create --region RegionOne metering admin http://${api_address}:8777 ) > /dev/null 2>&1
		fi

		print -n "\tAodh"

		openstack service show aodh > /dev/null 2>&1
		if [[ $? == 1 ]]; then
			( openstack service create --name aodh --description "Telemetry" alarming
			openstack user create --domain default --password ${keystone_aodh_password} aodh
			openstack role add --project service --user aodh admin

			openstack endpoint create --region RegionOne alarming public http://${api_address}:8042
			openstack endpoint create --region RegionOne alarming internal http://${api_address}:8042
			openstack endpoint create --region RegionOne alarming admin http://${api_address}:8042 ) > /dev/null 2>&1
		fi

		print -n "\tHeat"

		(openstack service show heat && openstack service show heat-cfn) > /dev/null 2>&1
		if [[ $? == 1 ]]; then
			( openstack service create --name heat --description "Orchestration" orchestration
			openstack service create --name heat-cfn --description "Orchestration"  cloudformation

			openstack user create --domain default --password ${keystone_heat_password} heat
			openstack role add --project service --user heat admin

			openstack endpoint create --region RegionOne orchestration public http://${api_address}:8004/v1/%\(tenant_id\)s
			openstack endpoint create --region RegionOne orchestration internal http://${api_address}:8004/v1/%\(tenant_id\)s
			openstack endpoint create --region RegionOne orchestration admin http://${api_address}:8004/v1/%\(tenant_id\)s

			openstack endpoint create --region RegionOne cloudformation public http://${api_address}:8000/v1
			openstack endpoint create --region RegionOne cloudformation internal http://${api_address}:8000/v1
			openstack endpoint create --region RegionOne cloudformation admin http://${api_address}:8000/v1

			openstack domain create --description "Stack projects and users" heat
			openstack user create --domain heat --password PwcBSrwEejnX7SP3M heat_domain_admin
			openstack role add --domain heat --user heat_domain_admin admin

			openstack role create heat_stack_owner
			openstack role add --project admin --user admin heat_stack_owner

			openstack role create heat_stack_user ) > /dev/null 2>&1
		fi
	fi

	if [[ "${DESIGNATE}" == true ]]; then
		print -n "\tDesignate"

		openstack service show designate > /dev/null 2>&1
		if [[ $? == 1 ]]; then
			( openstack service create --name designate --description "Designate DNS Service" dns
			openstack user create --domain default --password ${mysql_designate_password} designate
			openstack role add --project service --user designate admin

			openstack endpoint create --region RegionOne dns public http://${api_address}:9001
			openstack endpoint create --region RegionOne dns internal http://${api_address}:9001
			openstack endpoint create --region RegionOne dns admin http://${api_address}:9001 ) > /dev/null 2>&1
		fi
	fi

	if [[ "${MANILA}" == true ]]; then
		print -n "\tManila"

		(openstack service show manila && openstack service show manilav2) > /dev/null 2>&1
		if [[ $? == 1 ]]; then
			( openstack service create --name manila --description "OpenStack Shared File Systems" share
			openstack service create --name manilav2 --description "OpenStack Shared File Systems" sharev2
			openstack user create --domain default --password ${mysql_manila_password} manila
			openstack role add --project service --user manila admin

			openstack endpoint create --region RegionOne share public http://${api_address}:8786/v1/%\(tenant_id\)s
			openstack endpoint create --region RegionOne share internal http://${api_address}:8786/v1/%\(tenant_id\)s
			openstack endpoint create --region RegionOne share admin http://${api_address}:8786/v1/%\(tenant_id\)s

			openstack endpoint create --region RegionOne sharev2 public http://${api_address}:8786/v2/%\(tenant_id\)s
			openstack endpoint create --region RegionOne sharev2 internal http://${api_address}:8786/v2/%\(tenant_id\)s
			openstack endpoint create --region RegionOne sharev2 admin http://${api_address}:8786/v2/%\(tenant_id\)s ) > /dev/null 2>&1
		fi
	fi

	if [[ "${MANILA}" == true ]]; then
		print -n "\tMurano"

		openstack service show murano > /dev/null 2>&1
		if [[ $? == 1 ]]; then
			( openstack service create --name murano --description "Murano Application Catalog" application-catalog
			openstack user create --domain default --password ${mysql_murano_password} murano
			openstack role add --project service --user murano admin

			openstack endpoint create --region RegionOne application-catalog public http://${api_address}:8082/
			openstack endpoint create --region RegionOne application-catalog internal http://${api_address}:8082/
			openstack endpoint create --region RegionOne application-catalog admin http://${api_address}:8082/ ) > /dev/null 2>&1
		fi
	fi
}

function install_keystone()
{
	print "Installing Keystone"

	( rpm -q openstack-keystone || yum -y -q install openstack-keystone httpd mod_wsgi ) > /dev/null

	openstack-config --set ${keystone_config_file} DEFAULT admin_token ${admin_token}
	openstack-config --set ${keystone_config_file} DEFAULT log_dir /var/log/keystone
	# openstack-config --set ${keystone_config_file} DEFAULT verbose False

	openstack-config --set ${keystone_config_file} database connection mysql+pymysql://keystone:${mysql_keystone_password}@${api_address}/keystone

	openstack-config --set ${keystone_config_file} token provider fernet
	openstack-config --set ${keystone_config_file} token expiration 14400

	if [[ ! -f /var/lib/keystone/db_sync.lock ]]; then
		su -s /bin/sh -c "keystone-manage db_sync" keystone && touch /var/lib/keystone/db_sync.lock
	fi

	if [[ ! -f /etc/keystone/fernet-keys/0 || ! -f /etc/keystone/fernet-keys/1 ]]; then
		keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
	fi

	egrep "^ServerName $(hostname -s)" /etc/httpd/conf/httpd.conf > /dev/null 2>&1
	if [[ $? == 1 ]]; then
		sed -i "s/^#ServerName www.example.com:80/ServerName $(hostname -s)/g" /etc/httpd/conf/httpd.conf
	fi

	cat <<-HERE > /etc/httpd/conf.d/keystone.conf
	Listen 5000
	Listen 35357

	<VirtualHost *:5000>

		<Directory /usr/bin>
			<IfVersion >= 2.4>
				Require all granted
			</IfVersion>
			<IfVersion < 2.4>
				Order allow,deny
				Allow from all
			</IfVersion>
		</Directory>

		WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
		WSGIProcessGroup keystone-public
		WSGIScriptAlias / /usr/bin/keystone-wsgi-public
		WSGIApplicationGroup %{GLOBAL}
		WSGIPassAuthorization On
		<IfVersion >= 2.4>
		  ErrorLogFormat "%{cu}t %M"
		</IfVersion>

		LogLevel info

		ErrorLog  /var/log/httpd/keystone-error.log
		CustomLog /var/log/httpd/keystone-access.log combined

	</VirtualHost>

	<VirtualHost *:35357>

		<Directory /usr/bin>
			<IfVersion >= 2.4>
				Require all granted
			</IfVersion>
			<IfVersion < 2.4>
				Order allow,deny
				Allow from all
			</IfVersion>
		</Directory>

		WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
		WSGIProcessGroup keystone-admin
		WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
		WSGIApplicationGroup %{GLOBAL}
		WSGIPassAuthorization On
		<IfVersion >= 2.4>
		  ErrorLogFormat "%{cu}t %M"
		</IfVersion>

		LogLevel info

		ErrorLog  /var/log/httpd/keystone-error.log
		CustomLog /var/log/httpd/keystone-access.log combined

	</VirtualHost>
	HERE

	systemctl is-enabled openstack-keystone > /dev/null 2>&1 && systemctl disable openstack-keystone
	systemctl is-active openstack-keystone > /dev/null 2>&1 && ( systemctl stop openstack-keystone && sleep 5 && print -s "DONE" )

	__enable_service httpd
	__start_service httpd

	print -s "DONE"
}
