#!/bin/bash
FILE=/tmp/import_prod_done

if [ -f $FILE ]
then
	echo "File $FILE exists..."
else
	psql discourse < /tmp/images/production-image.sql
    touch /tmp/import_prod_done
fi