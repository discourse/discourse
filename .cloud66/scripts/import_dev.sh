#!/bin/bash
FILE=/tmp/import_dev_done

if [ -f $FILE ]
then
	echo "File $FILE exists..."
else
	psql $POSTGRESQL_DATABASE < /tmp/images/development-image.sql
    touch /tmp/import_dev_done
fi