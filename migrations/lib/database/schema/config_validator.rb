# frozen_string_literal: true

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

      validate_output_config(config)
      validate_schema_config(config)
      validate_plugins(config)

      self
    end

    def has_errors?
      @errors.any?
    end

    private

    def validate_with_json_schema(config)
      Validation::JsonSchemaValidator.new(config, @errors).validate
    end

    def validate_output_config(config)
      Validation::OutputConfigValidator.new(config, @errors).validate
    end

    def validate_schema_config(config)
      Validation::SchemaConfigValidator.new(config, @errors).validate
    end

    def validate_plugins(config)
      Validation::PluginConfigValidator.new(config, @errors).validate
    end
  end
end
