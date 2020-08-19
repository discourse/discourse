#!/bin/bash

set -e

COMMANDS="debug help logtail show stop adduser fg kill quit run wait console foreground logreopen reload shell status"
START="start restart zeoserver"
CMD="bin/instance"

CONF_FILES=(
	"parts/instance/etc/zope.conf"
)

#replace_conf(){
#	for arg in "$@" ; do
#		local key="$( cut -f1 -d'=' <<<"${arg}" )"
#		local value="$( cut -f2- -d'=' <<<"${arg}" )"
#		for f in "${CONF_FILES[@]}" ; do
#			sed -i s";${key};${value};" "${f}"
#		done
#	done
#}

parse_env(){
	if [ -r "$1" ] ; then
		while IFS="=" read key value  ; do
			export "${key}=${value}"
		done<<<"$( egrep '^[^#]+=.*' "$1" )"
	fi
}

bootstrap_conf(){
	# Fixing permissions
	find /app -not -user discourse -exec chown discourse:discourse {} \+

	gosu discourse bundle config build.nokogiri --use-system-libraries
	gosu discourse bundle config set deployment 'true'
	gosu discourse bundle config set without 'test:development'

	gosu discourse bundle config set DISCOURSE_DB_HOST "${POSTGRES_HOST}"
	gosu discourse bundle config set DISCOURSE_DB_PORT "${POSTGRES_PORT}"
	gosu discourse bundle config set DISCOURSE_DB_NAME "${POSTGRES_DB_NAME}"
	gosu discourse bundle config set DISCOURSE_DB_USERNAME "${POSTGRES_USER}"
	gosu discourse bundle config set DISCOURSE_DB_PASSWORD "${POSTGRES_PASSWORD}"

	gosu discourse bundle config set DISCOURSE_REDIS_HOST "${REDIS_HOST}"
	gosu discourse bundle config set DISCOURSE_REDIS_PORT "${REDIS_PORT}"
	gosu discourse bundle config set DISCOURSE_REDIS_PASSWORD "${REDIS_PASSWORD}"

	#gosu discourse bundle exec rake admin:create
	#gosu discourse bundle exec rake user:create["name","email","password","admin"]
}

parse_env '/env.sh'
parse_env '/run/secrets/env.sh'

if [[ "start" == *"$1"* ]]; then
	/wait-for "${POSTGRES_HOST}:${POSTGRES_PORT}" -- echo DB "${POSTGRES_HOST}:${POSTGRES_PORT}" started
	bootstrap_conf

	gosu discourse bundle exec rake db:create 
	gosu discourse bundle exec rake db:migrate
	#gosu discourse mailcatcher --http-ip 0.0.0.0
	exec gosu discourse bundle exec rails server --binding="0.0.0.0" --port="${DISCOURSE_PORT}"
elif [[ "bundle" == "$1" ]]; then
	bootstrap_conf

	exec gosu discourse $@
elif [[ "healthcheck" == "$1" ]]; then
	nc -z -w5 127.0.0.1 "${DISCOURSE_PORT}" || exit 1
	exit 0
fi

exec "$@"

