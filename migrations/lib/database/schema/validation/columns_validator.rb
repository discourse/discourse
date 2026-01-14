# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class ColumnsValidator < BaseValidator
    def validate(table_name, copy_of_table_name = nil)
      @table_name = table_name
      columns = @schema_config[:tables][table_name.to_sym][:columns] || {}

      @existing_column_names = find_existing_column_names(table_name, copy_of_table_name)
      @added_column_names = columns[:add]&.map { |column| column[:name] } || []
      @included_column_names = columns[:include] || []
      @excluded_column_names = columns[:exclude] || []
      @modified_column_names = columns[:modify]&.map { |column| column[:name] } || []
      @global = ::Migrations::Database::Schema::GlobalConfig.new(@schema_config)

      validated_added_columns
      validate_included_columns
      validate_excluded_columns
      validate_modified_columns
      validate_any_columns_configured
    end

    private

    def find_existing_column_names(table_name, copy_of_table_name)
      table_name = copy_of_table_name if copy_of_table_name.present?
      @db.columns(table_name).map { |c| c.name }
    end

    def validated_added_columns
      if (column_names = @existing_column_names & @added_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.added_columns_exist",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end
    end

    def validate_included_columns
      if (column_names = @included_column_names - @existing_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.included_columns_missing",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end
    end

    def validate_excluded_columns
      if (column_names = @excluded_column_names - @existing_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.excluded_columns_missing",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end
    end

    def validate_modified_columns
      if (column_names = @modified_column_names - @existing_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.modified_columns_missing",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end

      if (column_names = @modified_column_names & @included_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.modified_columns_included",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end

      if (column_names = @modified_column_names & @excluded_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.modified_columns_excluded",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end

      if (column_names = @modified_column_names & @global.excluded_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.modified_columns_globally_excluded",
          table_name: @table_name,
          column_names: sort_and_join(column_names),
        )
      end
    end

    def configured_column_names
      if @included_column_names.any?
        included_column_names = @included_column_names
        modified_column_names = @modified_column_names
      else
        included_column_names = @existing_column_names - @excluded_column_names
        modified_column_names = included_column_names & @modified_column_names
      end

      column_names = (included_column_names + modified_column_names).uniq & @existing_column_names
      column_names - @global.excluded_column_names + @added_column_names
    end

    def validate_any_columns_configured
      column_names = configured_column_names

      if column_names.empty?
        @errors << I18n.t("schema.validator.tables.no_columns_configured", table_name: @table_name)
      end
    end
  end
end
