#!/bin/bash
SCRIPTPATH=$(cd "$(dirname "$0")" >/dev/null; pwd -P)
SOURCE_DIR=$(cd "$SCRIPTPATH" && cd ../.. && pwd -P)
DATA_DIR=$SOURCE_DIR/data/postgres

# Should this also run /etc/runit/1.d/ensure_database, or will that
# happen automatically? -- It will happen, but restarting the container is required
docker run -it -v $DATA_DIR:/shared/postgres_data discourse/discourse_dev:release /bin/bash -c "rm -fr /shared/postgres_data/*"
docker restart discourse_dev
echo "Creating admin user..."
"${SCRIPTPATH}/rake" admin:create
