#!/bin/bash
FILE=/tmp/curl_done

if [ -f $FILE ]
then
	echo "File $FILE exists..."
else
	curl localhost
    curl localhost
    curl localhost
    curl localhost
    curl localhost
    touch /tmp/curl_done
fi