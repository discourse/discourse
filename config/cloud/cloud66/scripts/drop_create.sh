#!/bin/bash
FILE=/tmp/drop_create_done

if [ -f $FILE ]
then
	echo "File $FILE exists..."
else
	cd $RAILS_STACK_PATH
    bundle exec rake db:drop db:create
    touch /tmp/drop_create_done
fi