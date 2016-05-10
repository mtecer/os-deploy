function install_memcache()
{
    print "Installing Memcache"

    ( rpm -q memcached || yum -y -q install memcached python-memcached ) > /dev/null

    egrep 'OPTIONS="-l 127.0.0.1"' /etc/sysconfig/memcached > /dev/null 2>&1
    if [[ $? == 1 ]]; then
        sed -i 's/OPTIONS=""/OPTIONS="-l 127.0.0.1"/g' /etc/sysconfig/memcached
    fi

    __enable_service memcached
    __start_service memcached

    print -s "DONE"
}
