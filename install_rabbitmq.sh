function install_rabbitmq()
{
    print "Installing RabbitMQ"

    echo "rabbitmq    soft    nofile    8192" >  /etc/security/limits.d/rabbitmq.conf
    echo "rabbitmq    hard    nofile    8192" >> /etc/security/limits.d/rabbitmq.conf

    # ( rpm -q erlang-solutions || yum -y -q install http://packages.erlang-solutions.com/erlang-solutions-1.0-1.noarch.rpm ) > /dev/null

    # ( rpm -q rabbitmq-server || yum -y -q install http://www.rabbitmq.com/releases/rabbitmq-server/v3.6.1/rabbitmq-server-3.6.1-1.noarch.rpm ) > /dev/null
    ( rpm -q rabbitmq-server || yum -y -q install rabbitmq-server ) > /dev/null

    echo "NODENAME=rabbit@localhost"        >  /etc/rabbitmq/rabbitmq-env.conf
    echo "RABBITMQ_NODE_IP_ADDRESS=0.0.0.0" >> /etc/rabbitmq/rabbitmq-env.conf

    __enable_service rabbitmq-server
    __start_service rabbitmq-server

    rabbitmqctl list_users | grep ${rabbitmq_userid} > /dev/null 2>&1
    if [[ $? == 1 ]]; then
        ( rabbitmqctl delete_user guest
        rabbitmqctl add_user ${rabbitmq_userid} ${rabbitmq_password}
        rabbitmqctl set_user_tags ${rabbitmq_userid} administrator
        rabbitmqctl set_permissions -p / ${rabbitmq_userid} ".*" ".*" ".*"

        rabbitmq-plugins enable rabbitmq_management ) > /dev/null
    fi

    print -s "DONE"
}