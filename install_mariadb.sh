function install_mysql()
{
	print "Installing MariaDB"

	( rpm -q mariadb-server || yum -y -q install socat innotop mariadb-galera-server mariadb-galera-common mariadb-libs mariadb-bench rsync mariadb mariadb-server python2-PyMySQL ) > /dev/null

	echo "mysqld      soft    nofile    8192" >  /etc/security/limits.d/mysql.conf
	echo "mysqld      hard    nofile    8192" >> /etc/security/limits.d/mysql.conf

	cat <<-HERE > /etc/my.cnf.d/galera.cnf
	[mysqld]
	bind-address=0.0.0.0
	binlog_format=ROW
	default-storage-engine=innodb
	innodb_autoinc_lock_mode=2

	wsrep_auto_increment_control=1
	wsrep_causal_reads=0
	wsrep_certify_nonPK=1
	wsrep_cluster_address=gcomm://
	wsrep_cluster_name="galera"
	wsrep_convert_LOCK_to_trx=0
	wsrep_debug=0
	wsrep_drupal_282555_workaround=0
	wsrep_max_ws_rows=131072
	wsrep_max_ws_size=1073741824
	wsrep_on=ON
	wsrep_node_address=$(hostname -i)
	wsrep_node_name='$(hostname -s)'
	wsrep_notify_cmd=
	wsrep_provider=/usr/lib64/galera/libgalera_smm.so
	wsrep_retry_autocommit=1
	wsrep_slave_threads=1
	wsrep_sst_auth=galera_admin:${mysql_root_password}
	wsrep_sst_method=rsync
	HERE

	cat <<-HERE > /etc/my.cnf.d/mariadb_openstack.cnf
	[mysqld]
	open_files_limit = 4096
	max_connections = 4096
	bind-address = 0.0.0.0
	default-storage-engine = innodb
	innodb_file_per_table
	collation-server = utf8_general_ci
	init-connect = 'SET NAMES utf8'
	character-set-server = utf8
	HERE

	if [[ ! -d /etc/systemd/system/mariadb.service.d ]]; then
		mkdir /etc/systemd/system/mariadb.service.d
	fi

	echo "[Service]"            >  /etc/systemd/system/mariadb.service.d/limits.conf
	echo "LimitNOFILE=8192"     >> /etc/systemd/system/mariadb.service.d/limits.conf
	echo "LimitMEMLOCK=8192"    >> /etc/systemd/system/mariadb.service.d/limits.conf

	systemctl daemon-reload

	__enable_service mariadb
	__start_service mariadb

	mysql -u root <<-HERE > /dev/null 2>&1
	UPDATE mysql.user SET Password=PASSWORD("${mysql_root_password}") WHERE User='root';
	DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
	DELETE FROM mysql.user WHERE User='';
	DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';

	GRANT ALL PRIVILEGES ON *.* TO 'galera_admin'@'%' IDENTIFIED BY "${mysql_root_password}" WITH GRANT OPTION;
	FLUSH PRIVILEGES;
	HERE

	mysql -u root -p${mysql_root_password} <<-HERE > /dev/null 2>&1
	UPDATE mysql.user SET Password=PASSWORD("${mysql_root_password}") WHERE User='root';
	DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
	DELETE FROM mysql.user WHERE User='';
	DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';

	CREATE DATABASE keystone;
	GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY "${mysql_keystone_password}";

	CREATE DATABASE glance;
	GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY "${mysql_glance_password}";

	CREATE DATABASE nova;
	CREATE DATABASE nova_api;
	GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY "${mysql_nova_password}";
	GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY "${mysql_nova_password}";

	CREATE DATABASE neutron;
	GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY "${mysql_neutron_password}";

	CREATE DATABASE cinder;
	GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY "${mysql_cinder_password}";

	CREATE DATABASE aodh;
	GRANT ALL PRIVILEGES ON aodh.* TO 'aodh'@'%' IDENTIFIED BY "${mysql_aodh_password}";

	CREATE DATABASE heat;
	GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'%' IDENTIFIED BY "${mysql_heat_password}";

	FLUSH PRIVILEGES;
	HERE

	# CREATE DATABASE designate;
	# CREATE DATABASE designate_pool_manager;

	# GRANT ALL ON designate.* TO 'designate'@'%' IDENTIFIED BY "${mysql_designate_password}";
	# GRANT ALL ON designate_pool_manager.* TO 'designate'@'%' IDENTIFIED BY "${mysql_designate_password}";

	# CREATE DATABASE manila;
	# GRANT ALL PRIVILEGES ON manila.* TO 'manila'@'%' IDENTIFIED BY "${mysql_manila_password}";

	# CREATE DATABASE murano;
	# GRANT ALL PRIVILEGES ON murano.* TO 'murano'@'%' IDENTIFIED BY "${mysql_murano_password}";

	print -s "DONE"
}