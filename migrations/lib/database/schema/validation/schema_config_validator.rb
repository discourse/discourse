# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class SchemaConfigValidator
    def initialize(config, errors)
      @config = config
      @errors = errors
    end

    def validate
      ActiveRecord::Base.with_connection do |db|
        GloballyExcludedTablesValidator.new(@config, @errors, db).validate
        GloballyConfiguredColumnsValidator.new(@config, @errors, db).validate
        TablesValidator.new(@config, @errors, db).validate
      end
    end
  end
end
