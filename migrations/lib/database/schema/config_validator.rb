# frozen_string_literal: true

require "json_schemer"

module Migrations::Database::Schema
  class ConfigValidator
    attr_reader :errors

    def initialize
      @errors = []
    end

    def validate(config)
      @errors.clear

      validate_with_json_schema(config)
      return self if has_errors?

      validate_output_config(config[:output])
      validate_schema_config(config[:schema])
      validate_plugins(config[:plugins])

      self
    end

    def has_errors?
      @errors.any?
    end

    private

    def validate_with_json_schema(config)
      Validation::JsonSchemaValidator.new(config, @errors).validate
    end

    def validate_output_config(output_config)
      Validation::OutputConfigValidator.new(output_config, @errors).validate
    end

    def validate_schema_config(schema_config)
      Validation::SchemaConfigValidator.new(schema_config, @errors).validate
    end

    def validate_plugins(plugin_names)
      Validation::PluginConfigValidator.new(plugin_names, @errors).validate
    end
  end
end
