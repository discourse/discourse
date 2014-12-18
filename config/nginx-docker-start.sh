#!/bin/bash

set -e

discourse=`dirname $0`/..
root=`cat $discourse/tmp/root`

echo removing unused and stale files
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/conf.d/*
mkdir -p /var/nginx/cache /var/run /var/log/nginx

echo generating nginx.conf
cat $discourse/config/nginx.sample.conf |
    sed 's|server unix:/var/www/discourse/tmp/sockets/thin.[0-9]*.sock;|server discourse:3000;|' |
    sed "s|/var/www/discourse|$discourse|g" |
    sed 's/server_name.+$/server_name _/' |
    sed "s|location / |location $root |" |
    sed 's/root \$public;/alias $public;/' > /etc/nginx/conf.d/discourse.conf

exec nginx -g 'daemon off;'
