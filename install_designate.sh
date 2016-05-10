function __install_bind()
{
	print "Installing BIND9"

	( rpm -q bind bind-utils || yum -y -q install bind bind-utils ) > /dev/null

	if [[ ! -f /etc/named.conf.orig ]]; then
		cp -a /etc/named.conf /etc/named.conf.orig
	fi

	sed -i -e "s/listen-on port.*/listen-on port 53 { 127.0.0.1; ${api_address}; };/" /etc/named.conf

	rndc-confgen -a

	cat <<-HERE>> /etc/named.conf
	logging {
		channel default_file {
			file "/var/log/named/default.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel general_file {
			file "/var/log/named/general.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel database_file {
			file "/var/log/named/database.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel security_file {
			file "/var/log/named/security.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel config_file {
			file "/var/log/named/config.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel resolver_file {
			file "/var/log/named/resolver.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel xfer-in_file {
			file "/var/log/named/xfer-in.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel xfer-out_file {
			file "/var/log/named/xfer-out.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel notify_file {
			file "/var/log/named/notify.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel client_file {
			file "/var/log/named/client.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel unmatched_file {
			file "/var/log/named/unmatched.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel queries_file {
			file "/var/log/named/queries.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel network_file {
			file "/var/log/named/network.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel update_file {
			file "/var/log/named/update.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel dispatch_file {
			file "/var/log/named/dispatch.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel dnssec_file {
			file "/var/log/named/dnssec.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};
		channel lame-servers_file {
			file "/var/log/named/lame-servers.log" versions 3 size 5m;
			severity dynamic;
			print-time yes;
		};

		category default { default_file; };
		category general { general_file; };
		category database { database_file; };
		category security { security_file; };
		category config { config_file; };
		category resolver { resolver_file; };
		category xfer-in { xfer-in_file; };
		category xfer-out { xfer-out_file; };
		category notify { notify_file; };
		category client { client_file; };
		category unmatched { unmatched_file; };
		category queries { queries_file; };
		category network { network_file; };
		category update { update_file; };
		category dispatch { dispatch_file; };
		category dnssec { dnssec_file; };
		category lame-servers { lame-servers_file; };
	};
	HERE

	sed -i '/^options.*/i \include "/etc/rndc.key";\
	controls { \
	  inet 127.0.0.1 allow { localhost; } keys { "rndc-key"; }; \
	};' /etc/named.conf

	sed -i '/allow-query.*/d' /etc/named.conf
	sed -i '/recursion.*/d' /etc/named.conf

	sed -i '/^options.*/a \
	\tallow-new-zones yes;\
	\tallow-query { any; };\
	\tallow-notify { 127.0.0.1; };\
	\trecursion no;' /etc/named.conf

	cat <<-HERE > /etc/rndc.conf
	include "/etc/rndc.key";
	options {
	  default-key "rndc-key";
	  default-server 127.0.0.1;
	  default-port 953;
	};
	HERE

	named-checkconf /etc/named.conf

	chmod g+w /var/named
	chown named:named /etc/rndc.conf
	chown named:named /etc/rndc.key
	chmod 600 /etc/rndc.key

	__enable_service named
	__start_service named

	print -s "DONE"
}

function __install_designate__dashboard()
{
	mkdir -p /images/horizon
	cd /images/horizon

	git clone https://github.com/openstack/designate-dashboard.git
	cd /images/horizon/designate-dashboard/

	python setup.py sdist
	pip install dist/*.tar.gz

	cp designatedashboard/enabled/_1720_project_dns_panel.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
	cp designatedashboard/enabled/_1710_project_dns_panel_group.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/

	__restart_service httpd
	__restart_service memcached
}

function install_designate()
{
	print "Installing Designate"

	__install_bind

	( rpm -q openstack-designate-api openstack-designate-central openstack-designate-sink openstack-designate-pool-manager openstack-designate-mdns openstack-designate-common || yum -y install openstack-designate-api openstack-designate-central openstack-designate-sink openstack-designate-pool-manager openstack-designate-mdns openstack-designate-common python-designate python-designateclient openstack-designate-agent ) > /dev/null

	__configure_keystone ${designate_config_file} designate ${keystone_designate_password}

	__configure_oslo_messaging_rabbit ${designate_config_file}

	openstack-config --set ${designate_config_file} DEFAULT verbose False
	openstack-config --set ${designate_config_file} DEFAULT debug False

	openstack-config --set ${designate_config_file} storage:sqlalchemy connection mysql+pymysql://designate:${mysql_designate_password}@127.0.0.1/designate
	openstack-config --set ${designate_config_file} storage:sqlalchemy max_retries -1

	openstack-config --set ${designate_config_file} pool_manager_cache:sqlalchemy connection mysql+pymysql://designate:${mysql_designate_password}@127.0.0.1/designate_pool_manager
	openstack-config --set ${designate_config_file} pool_manager_cache:sqlalchemy max_retries -1

	openstack-config --set ${designate_config_file} oslo_messaging_notifications driver messagingv2
	openstack-config --set ${designate_config_file} oslo_messaging_notifications topics notifications_designate

	openstack-config --set ${designate_config_file} service:api api_host 0.0.0.0
	openstack-config --set ${designate_config_file} service:api api_port 9001
	openstack-config --set ${designate_config_file} service:api auth_strategy keystone
	openstack-config --set ${designate_config_file} service:api enable_api_v1 True
	openstack-config --set ${designate_config_file} service:api enabled_extensions_v1 "diagnostics, quotas, reports, sync, touch"
	openstack-config --set ${designate_config_file} service:api enable_api_v2 True
	openstack-config --set ${designate_config_file} service:api enabled_extensions_v2 "quotas, reports"

	pool_id=794ccc2c-d751-44fe-b57f-8894c9f5c842
	nameserver_id=$(uuidgen)
	target_id=$(uuidgen)

	openstack-config --set ${designate_config_file} service:pool_manager pool_id ${pool_id}
	openstack-config --set ${designate_config_file} service:pool_manager backends bind9

	openstack-config --set ${designate_config_file} pool:$pool_id nameservers ${nameserver_id}
	openstack-config --set ${designate_config_file} pool:$pool_id targets $target_id

	openstack-config --set ${designate_config_file} pool_nameserver:${nameserver_id} port 53
	openstack-config --set ${designate_config_file} pool_nameserver:${nameserver_id} host ${api_server}

	openstack-config --set ${designate_config_file} service:sink enabled_notification_handlers "nova_fixed, neutron_floatingip"

	openstack-config --set ${designate_config_file} handler:nova_fixed notification_topics notifications_designate
	openstack-config --set ${designate_config_file} handler:nova_fixed control_exchange nova
	openstack-config --set ${designate_config_file} handler:nova_fixed format "%(display_name)s.%(zone)s"

	openstack-config --set ${designate_config_file} handler:neutron_floatingip notification_topics notifications_designate
	openstack-config --set ${designate_config_file} handler:neutron_floatingip control_exchange neutron
	openstack-config --set ${designate_config_file} handler:neutron_floatingip format "%(octet0)s-%(octet1)s-%(octet2)s-% (octet3)s.%(zone)s"

	openstack-config --set ${designate_config_file} pool_target:$target_id type bind9
	openstack-config --set ${designate_config_file} pool_target:$target_id options "rndc_host: 127.0.0.1, rndc_port: 953, rndc_config_file: /etc/rndc.conf, rndc_key_file: /etc/rndc.key, port: 53, host: 127.0.0.1, clean_zonefile: false"
	openstack-config --set ${designate_config_file} pool_target:$target_id masters ${api_server}:5354

	openstack-config --set ${designate_config_file} handler:nova_fixed zone_id $DOMAINID
	openstack-config --set ${designate_config_file} handler:neutron_floatingip zone_id $DOMAINID

	openstack-config --set ${nova_config_file} oslo_messaging_notifications driver messagingv2
	openstack-config --set ${nova_config_file} oslo_messaging_notifications topics notifications,notifications_designate

	openstack-config --set ${neutron_config_file} oslo_messaging_notifications driver messagingv2
	openstack-config --set ${neutron_config_file} oslo_messaging_notifications topics notifications,notifications_designate

	( openstack-service restart nova ) > /dev/null 2>&1
	( openstack-service restart neutron ) > /dev/null 2>&1

	( designate-manage database sync ) > /dev/null 2>&1
	( designate-manage pool-manager-cache sync  ) > /dev/null 2>&1

	__enable_service designate-central
	__enable_service designate-api
	__enable_service designate-mdns
	__enable_service designate-pool-manager
	__enable_service designate-sink

	__start_service designate-central
	__start_service designate-api
	__start_service designate-mdns
	__start_service designate-pool-manager
	__start_service designate-sink

	designate-manage pool export_from_config
	designate-manage pool update
	designate-manage pool show_config
	designate-manage pool generate_file

	designate server-create --name ns.${dhcp_domain_name}.
	designate domain-create --name ${dhcp_domain_name}. --email mtecer@netsuite.com

	__install_designate__dashboard

	print -s "DONE"
}
