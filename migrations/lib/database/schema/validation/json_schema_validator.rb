# frozen_string_literal: true

require "json_schemer"

module Migrations::Database::Schema::Validation
  class JsonSchemaValidator
    def initialize(config, errors)
      @config = config
      @errors = errors
    end

    def validate
      schema = load_json_schema
      schemer = ::JSONSchemer.schema(schema)
      response = schemer.validate(@config)
      response.each { |r| @errors << transform_json_schema_errors(r) }
    end

    private

    def load_json_schema
      schema_path = File.join(::Migrations.root_path, "config", "json_schemas", "db_schema.json")
      JSON.load_file(schema_path)
    end

    def transform_json_schema_errors(response)
      error_message = response.fetch("error")

      error_message.gsub!(/value at (`.+?`) matches `not` schema/) do
        path = $1
        schema_pointer = response.fetch("schema_pointer")

        case schema_pointer
        in %r{/tables/}
          I18n.t("schema.validator.include_exclude_not_allowed", path:)
        else
          $1
        end
      end
      error_message
    end
  end
end
