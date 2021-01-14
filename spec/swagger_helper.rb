# frozen_string_literal: true

require 'rails_helper'
require "json/schema_builder"

# json-schema_builder config
# We want to validate and be strict here so that we error when we detect
# differences with the schema and the json response/request.
JSON::SchemaBuilder.configure do |opts|
  opts.validate_schema = true
  opts.strict = true
end

# Require schema files
Dir["./spec/requests/api/schemas/*.rb"].each { |file| require file }

# Require shared examples
Dir["./spec/requests/api/shared/*.rb"].each { |file| require file }

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.swagger_root = Rails.root.join('openapi').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under swagger_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a swagger_doc tag to the
  # the root example_group in your specs, e.g. describe '...', swagger_doc: 'v2/swagger.json'
  config.swagger_docs = {
    'openapi.yaml' => {
      openapi: '3.0.3',
      info: {
        title: 'Discourse API Documentation',
        version: 'latest'
      },
      paths: {},
      servers: [
        {
          url: 'https://{defaultHost}',
          variables: {
            defaultHost: {
              default: 'discourse.example.com'
            }
          }
        }
      ]
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The swagger_docs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.swagger_format = :yaml
end
