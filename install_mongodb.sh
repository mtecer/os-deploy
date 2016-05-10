function install_mongodb()
{
    print "Installing MongoDB"

    ( rpm -q mongodb-server || yum -y -q install mongodb-server mongodb ) > /dev/null

    egrep '^bind_ip|^smallfiles' /etc/mongod.conf > /dev/null 2>&1
    if [[ $? == 1 ]]; then
        sed -i 's/#bind_ip = 127.0.0.1/bind_ip = 127.0.0.1/' /etc/mongod.conf
        sed -i 's/#smallfiles = true/smallfiles = true/g' /etc/mongod.conf
    fi

    __enable_service mongod
    __start_service mongod

    echo 'db.getUsers()' | mongo -u ceilometer -p 'password' ceilometer > /dev/null 2>&1
    if [[ $? == 1 ]]; then
        ( mongo --host 127.0.0.1 --eval "db = db.getSiblingDB(\"ceilometer\"); db.addUser({user: \"ceilometer\", pwd: \"${mongod_ceilometer_password}\", roles: [ \"readWrite\", \"dbAdmin\" ]})" ) > /dev/null
    fi

    print -s "DONE"
}
