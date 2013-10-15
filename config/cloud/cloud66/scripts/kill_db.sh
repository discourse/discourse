#!/bin/bash
FILE=/tmp/kill_db_done

if [ -f $FILE ]
then
	echo "File $FILE exists..."
else
	ps xa | grep postgres: | grep $POSTGRESQL_DATABASE | grep -v grep | awk '{print $1}' | sudo xargs kill
    touch /tmp/kill_db_done
fi