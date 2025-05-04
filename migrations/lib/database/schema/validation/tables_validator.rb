# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class TablesValidator < BaseValidator
    def initialize(config, errors, db)
      super

      @existing_table_names = @db.tables
      @configured_tables = @schema_config[:tables]
      @configured_table_names = @configured_tables.keys.map(&:to_s)
      @excluded_table_names = @schema_config.dig(:global, :tables, :exclude) || []
    end

    def validate
      validate_excluded_tables
      validate_unconfigured_tables
      validate_copied_tables
      validate_columns
    end

    private

    def validate_excluded_tables
      table_names = @configured_table_names & @excluded_table_names

      if table_names.any?
        @errors << I18n.t(
          "schema.validator.tables.excluded_tables_configured",
          table_names: sort_and_join(table_names),
        )
      end
    end

    def validate_unconfigured_tables
      table_names = @existing_table_names - @configured_table_names - @excluded_table_names

      if table_names.any?
        @errors << I18n.t(
          "schema.validator.tables.not_configured",
          table_names: sort_and_join(table_names),
        )
      end
    end

    def validate_copied_tables
      @configured_tables.each do |_table_name, table_config|
        next unless table_config[:copy_of]

        if !@existing_table_names.include?(table_config[:copy_of])
          @errors << I18n.t(
            "schema.validator.tables.copy_table_not_found",
            table_name: table_config[:copy_of],
          )
        end
      end
    end

    def validate_columns
      @configured_tables.each do |table_name, table_config|
        validator = ColumnsValidator.new(@config, @errors, @db)

        if table_config[:copy_of]
          validator.validate(table_name.to_s, table_config[:copy_of])
        else
          validator.validate(table_name.to_s)
        end
      end
    end
  end
end
