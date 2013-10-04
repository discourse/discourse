#!/bin/bash
FILE=/tmp/production_rename_done

if [ -f $FILE ]
then
	echo "File $FILE exists..."
else
	source /var/.cloud66_env
    cd $RAILS_STACK_PATH/config/environments
    mv production.rb.sample production.rb
    touch /tmp/production_rename_done
fi