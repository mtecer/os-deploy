function install_haproxy()
{
	print "Installing HAProxy"

	# echo 'net.ipv4.ip_nonlocal_bind=1' > /etc/sysctl.d/bind_nonlocal_ip.conf
	# sysctl --system

	( rpm -q haproxy || yum -y -q install haproxy ) > /dev/null

	echo '$ModLoad imudp' > /etc/rsyslog.d/listen-udp.conf
	echo '$UDPServerRun 514' >> /etc/rsyslog.d/listen-udp.conf

	echo '$ModLoad imtcp' > /etc/rsyslog.d/listen-tcp.conf
	echo '$InputTCPServerRun 514' >> /etc/rsyslog.d/listen-tcp.conf

	echo 'local2.*                       /var/log/haproxy.log' > /etc/rsyslog.d/haproxy.conf
	echo '& stop' >> /etc/rsyslog.d/haproxy.conf

	systemctl restart rsyslog

	cat lib/haproxy/haproxy.cfg > /etc/haproxy/haproxy.cfg
	sed -i "s/%__API_ADDRESS__%/${api_address}/g" /etc/haproxy/haproxy.cfg
	sed -i "s/%__HAPROXY_ADMIN_PASSWORD__%/${haproxy_admin_password}/g" /etc/haproxy/haproxy.cfg

	chown root.root /etc/haproxy/haproxy.cfg
	chmod 0644 /etc/haproxy/haproxy.cfg

	# __enable_service haproxy
	# __start_service haproxy

	print -s "DONE"
}
