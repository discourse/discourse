# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class TablesValidator < BaseValidator
    def initialize(config, errors, db)
      super

      @existing_table_names = @db.tables
      @configured_table_names = @schema_config[:tables].keys.map(&:to_s)
      @excluded_table_names = @schema_config.dig(:global, :tables, :exclude) || []
    end

    def validate
      validate_excluded_tables
      validate_unconfigured_tables
      validate_columns
    end

    private

    def validate_excluded_tables
      if (table_names = @configured_table_names & @excluded_table_names).any?
        @errors << I18n.t(
          "schema.validator.tables.excluded_tables_configured",
          table_names: sort_and_join(table_names),
        )
      end
    end

    def validate_unconfigured_tables
      if (
           table_names = @existing_table_names - @configured_table_names - @excluded_table_names
         ).any?
        @errors << I18n.t(
          "schema.validator.tables.not_configured",
          table_names: sort_and_join(table_names),
        )
      end
    end

    def validate_columns
      @configured_table_names.each do |table_name|
        ColumnsValidator.new(@config, @errors, @db).validate(table_name)
      end
    end
  end
end
