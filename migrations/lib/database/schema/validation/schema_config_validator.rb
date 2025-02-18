# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class SchemaConfigValidator
    def initialize(schema_config, errors)
      @schema_config = schema_config
      @errors = errors
    end

    def validate
      ActiveRecord::Base.with_connection do |db|
        GloballyExcludedTablesValidator.new(@schema_config, db, @errors).validate
        GloballyConfiguredColumnsValidator.new(@schema_config, db, @errors).validate
        TablesValidator.new(@schema_config, db, @errors).validate
        ColumnsValidator.new(@schema_config, db, @errors).validate
      end
    end
  end
end
