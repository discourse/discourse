#!/bin/bash
FILE=/tmp/migrate_done

if [ -f $FILE ]
then
	echo "File $FILE exists..."
else
	cd $RAILS_STACK_PATH
    bundle exec rake db:migrate db:seed_fu
    touch /tmp/migrate_done
fi