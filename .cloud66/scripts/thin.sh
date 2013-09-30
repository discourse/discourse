#!/bin/bash
FILE=/tmp/thin_done

if [ -f $FILE ]
then
	echo "File $FILE exists..."
else
	source /var/.cloud66_env
    cd $RAILS_STACK_PATH
    echo "" >> config/thin.yml
    echo "chdir: $RAILS_STACK_PATH" >> config/thin.yml
    echo "environment: $RAILS_ENV" >> config/thin.yml
    echo "log: $RAILS_STACK_PATH/log/thin.log" >> config/thin.yml
    touch /tmp/thin_done
fi