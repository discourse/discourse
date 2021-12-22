#!/bin/sh
if [[ -z "${DISCOURSE_REPO_BASE_DIRECTORY}" ]]; then
  echo "Set DISCOURSE_REPO_BASE_DIRECTORY before running this script."
else
  discourse_api_docs_dir="${DISCOURSE_REPO_BASE_DIRECTORY}/discourse_api_docs/"
  RUBYOPT="W0" rake rswag:specs:swaggerize && cp openapi/openapi.yaml ${discourse_api_docs_dir}openapi.yml
  (cd $discourse_api_docs_dir ; sh ${discourse_api_docs_dir}openapi_changed.sh)

  echo "Swagger openapi.yml file copied to $discourse_api_docs_dir"
fi
