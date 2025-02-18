# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class ColumnsValidator < BaseValidator
    def validate
      global = ::Migrations::Database::Schema::GlobalConfig.new(@schema_config)

      @schema_config[:tables].each do |table_name, table_config|
        validate_columns_of_table(table_name.to_s, table_config[:columns], global)
      end
    end

    private

    def validate_columns_of_table(table_name, columns, global)
      existing_column_names = @db.columns(table_name).map { |c| c.name }

      added_column_names = columns[:add]&.map { |column| column[:name] } || []
      validated_added_columns(table_name, existing_column_names, added_column_names)

      included_column_names = columns[:include] || []
      validate_included_columns(table_name, existing_column_names, included_column_names)

      excluded_column_names = columns[:exclude] || []
      validate_excluded_columns(table_name, existing_column_names, excluded_column_names)

      modified_column_names = columns[:modify]&.map { |column| column[:name] } || []
      validate_modified_columns(
        table_name,
        existing_column_names,
        modified_column_names,
        included_column_names,
        excluded_column_names,
      )

      validate_column_usage(
        table_name,
        global,
        existing_column_names,
        modified_column_names,
        included_column_names,
        excluded_column_names,
        added_column_names,
      )
    end

    def validated_added_columns(table_name, existing_column_names, added_column_names)
      if (column_names = existing_column_names & added_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.added_columns_exist",
          table_name:,
          column_names: sort_and_join(column_names),
        )
      end
    end

    def validate_included_columns(table_name, existing_column_names, included_column_names)
      if (column_names = included_column_names - existing_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.included_columns_missing",
          table_name:,
          column_names: sort_and_join(column_names),
        )
      end
    end

    def validate_excluded_columns(table_name, existing_column_names, excluded_column_names)
      if (column_names = excluded_column_names - existing_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.excluded_columns_missing",
          table_name:,
          column_names: sort_and_join(column_names),
        )
      end
    end

    def validate_modified_columns(
      table_name,
      existing_column_names,
      modified_column_names,
      included_column_names,
      excluded_column_names
    )
      if (column_names = modified_column_names - existing_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.modified_columns_missing",
          table_name:,
          column_names: sort_and_join(column_names),
        )
      end

      if (column_names = modified_column_names & included_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.modified_columns_included",
          table_name:,
          column_names: sort_and_join(column_names),
        )
      end

      if (column_names = modified_column_names & excluded_column_names).any?
        @errors << I18n.t(
          "schema.validator.tables.modified_columns_excluded",
          table_name:,
          column_names: sort_and_join(column_names),
        )
      end
    end

    def validate_column_usage(
      table_name,
      global,
      existing_column_names,
      modified_column_names,
      included_column_names,
      excluded_column_names,
      added_column_names
    )
      if excluded_column_names.empty?
        column_names =
          existing_column_names - included_column_names - modified_column_names -
            global.excluded_column_names.to_a + added_column_names

        if column_names.any?
          @errors << I18n.t(
            "schema.validator.tables.not_all_columns_configured",
            table_name:,
            column_names: sort_and_join(column_names),
          )
        end
      else
        column_names =
          existing_column_names - excluded_column_names + modified_column_names -
            global.excluded_column_names.to_a + added_column_names

        if column_names.empty?
          @errors << I18n.t(
            "schema.validator.tables.no_columns_configured",
            table_name:,
            column_names: sort_and_join(column_names),
          )
        end
      end
    end
  end
end
