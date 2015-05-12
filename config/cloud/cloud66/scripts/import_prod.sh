#!/bin/bash
FILE=/tmp/import_prod_done

if [ -f $FILE ]
then
	echo "File $FILE exists..."
else
	psql $POSTGRESQL_DATABASE < /tmp/images/production-image.sql
    touch /tmp/import_prod_done
fi