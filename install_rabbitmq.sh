function install_rabbitmq()
{
    print "Installing RabbitMQ"

    echo "rabbitmq    soft    nofile    8192" >  /etc/security/limits.d/rabbitmq.conf
    echo "rabbitmq    hard    nofile    8192" >> /etc/security/limits.d/rabbitmq.conf

    ( rpm -q rabbitmq-server || yum -y -q install rabbitmq-server ) > /dev/null

    if [[ ! -f /var/lib/rabbitmq/.erlang.cookie ]]; then
        echo 'AFETHWOFTFMRAMEMQCWK' > /var/lib/rabbitmq/.erlang.cookie
        chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
        chmod 0400 /var/lib/rabbitmq/.erlang.cookie
    fi

    # rabbitmqctl stop_app
    # rabbitmqctl join_cluster --ram rabbit@oa-controller01
    # rabbitmqctl start_app
    # rabbitmqctl cluster_status
    # rabbitmqctl set_policy ha-all '^(?!amq\.).*' '{"ha-mode": "all"}'

    echo "NODENAME=rabbit@$(hostname -s)"   >  /etc/rabbitmq/rabbitmq-env.conf
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