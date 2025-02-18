# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class SchemaConfigValidator
    def initialize(schema_config, errors)
      @schema_config = schema_config
      @errors = errors
      @db = ActiveRecord::Base.connection
    end

    def validate
      validate_globally_excluded_tables
      validate_globally_configured_columns
      validate_tables
      validate_columns
    end

    private

    def validate_globally_excluded_tables
      GloballyExcludedTablesValidator.new(@schema_config, @db, @errors).validate
    end

    def validate_globally_configured_columns
      GloballyConfiguredColumnsValidator.new(@schema_config, @db, @errors).validate
    end

    def validate_tables
      TablesValidator.new(@schema_config, @db, @errors).validate
    end

    def validate_columns
      ColumnsValidator.new(@schema_config, @db, @errors).validate
    end
  end
end
