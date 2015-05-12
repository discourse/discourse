#!/bin/bash
FILE=/tmp/curl_done

if [ -f $FILE ]
then
	echo "File $FILE exists..."
else
	curl --retry 5 localhost
    touch /tmp/curl_done
fi
