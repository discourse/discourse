# frozen_string_literal: true

require 'rails_helper'
require 'json_schemer'

# Require schema files
Dir["./spec/requests/api/schemas/*.rb"].each { |file| require file }

# Require shared spec examples
Dir["./spec/requests/api/shared/*.rb"].each { |file| require file }

def load_spec_schema(name)
  SpecSchemas::SpecLoader.new(name).load
end

def api_docs_description
  <<~HEREDOC
    This page contains the documentation on how to use Discourse through API calls.

    > Note: For any endpoints not listed you can follow the
    [reverse engineer the Discourse API](https://meta.discourse.org/t/-/20576)
    guide to figure out how to use an API endpoint.

    ### Request Content-Type

    The Content-Type for POST and PUT requests can be set to `application/x-www-form-urlencoded`,
    `multipart/form-data`, or `application/json`.

    ### Endpoint Names and Response Content-Type

    Most API endpoints provide the same content as their HTML counterparts. For example
    the URL `/categories` serves a list of categories, the `/categories.json` API provides the
    same information in JSON format.

    Instead of sending API requests to `/categories.json` you may also send them to `/categories`
    and add an `Accept: application/json` header to the request to get the JSON response.
    Sending requests with the `Accept` header is necessary if you want to use URLs
    for related endpoints returned by the API, such as pagination URLs.
    These URLs are returned without the `.json` prefix so you need to add the header in
    order to get the correct response format.

    ### Authentication

    Some endpoints do not require any authentication, pretty much anything else will
    require you to be authenticated.

    To become authenticated you will need to create an API Key from the admin panel.

    Once you have your API Key you can pass it in along with your API Username
    as an HTTP header like this:

    ```
    curl -X GET "http://127.0.0.1:3000/admin/users/list/active.json" \\
    -H "Api-Key: 714552c6148e1617aeab526d0606184b94a80ec048fc09894ff1a72b740c5f19" \\
    -H "Api-Username: system"
    ```

    and this is how POST requests will look:

    ```
    curl -X POST "http://127.0.0.1:3000/categories" \\
    -H "Content-Type: multipart/form-data;" \\
    -H "Api-Key: 714552c6148e1617aeab526d0606184b94a80ec048fc09894ff1a72b740c5f19" \\
    -H "Api-Username: system" \\
    -F "name=89853c20-4409-e91a-a8ea-f6cdff96aaaa" \\
    -F "color=49d9e9" \\
    -F "text_color=f0fcfd"
    ```

    ### Boolean values

    If an endpoint accepts a boolean be sure to specify it as a lowercase
    `true` or `false` value unless noted otherwise.
  HEREDOC
end

def direct_uploads_disclaimer
  <<~HEREDOC
    You must have the correct permissions and CORS settings configured in your
    external provider. We support AWS S3 as the default. See:

    https://meta.discourse.org/t/-/210469#s3-multipart-direct-uploads-4.

    An external file store must be set up and `enable_direct_s3_uploads` must
    be set to true for this endpoint to function.
  HEREDOC
end

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
      openapi: '3.1.0',
      info: {
        title: 'Discourse API Documentation',
        'x-logo': {
          url: 'https://discourse-meta.s3-us-west-1.amazonaws.com/optimized/3X/9/d/9d543e92b15b06924249654667a81441a55867eb_1_690x184.png',
        },
        version: 'latest',
        description: api_docs_description,
        license: {
          name: 'MIT',
          url: 'https://docs.discourse.org/LICENSE.txt'
        }
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
      ],
      components: {
        schemas: {
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The swagger_docs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.swagger_format = :yaml
end
