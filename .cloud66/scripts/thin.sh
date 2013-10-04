#!/bin/bash
FILE=/tmp/thin_done

if [ -f $FILE ]
then
	echo "File $FILE exists..."
else
	source /var/.cloud66_env
    cd $RAILS_STACK_PATH
    echo "
address: localhost
port: 3000
timeout: 30
pid: /tmp/web_server.pid
socket: /tmp/web_server.sock
max_conns: 1024
max_persistent_conns: 100
require: []
wait: 30
daemonize: true
chdir: $RAILS_STACK_PATH
environment: $RAILS_ENV
log: $RAILS_STACK_PATH/log/thin.log" > config/thin.yml
    touch /tmp/thin_done
fi