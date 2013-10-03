#!/bin/bash
FILE=/tmp/redis_done

if [ -f $FILE ]
then
	echo "File $FILE exists..."
else
	source /var/.cloud66_env
    cd $RAILS_STACK_PATH
    mv redis.yml.sample redis.yml
    touch /tmp/redis_done
fi