# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  class ResolvedSchemaValidator
    def initialize(resolved_schema)
      @schema = resolved_schema
      @errors = []
    end

    def validate
      @errors.clear

      @schema.tables.each { |table| validate_table(table) }
      @schema.enums.each { |enum| validate_enum(enum) }

      @errors
    end

    private

    def validate_table(table)
      column_names = table.columns.map(&:name).to_set

      validate_columns(table)
      validate_primary_key(table, column_names)
      validate_indexes(table, column_names)
      validate_constraints(table)
    end

    def validate_columns(table)
      table.columns.each do |column|
        if Migrations::Database::Schema::Helpers::VALID_DATATYPES.exclude?(column.datatype)
          @errors << "Table '#{table.name}': column '#{column.name}' has invalid datatype '#{column.datatype}'"
        end

        @errors << "Table '#{table.name}': column has empty name" if column.name.blank?

        if column.is_primary_key && column.nullable
          @errors << "Table '#{table.name}': primary key column '#{column.name}' should not be nullable"
        end
      end

      duplicates = table.columns.map(&:name).tally.filter_map { |n, c| n if c > 1 }
      if duplicates.any?
        @errors << "Table '#{table.name}': duplicate column names: #{duplicates.join(", ")}"
      end
    end

    def validate_primary_key(table, column_names)
      return unless table.primary_key_column_names

      missing = table.primary_key_column_names.reject { |pk| column_names.include?(pk) }
      if missing.any?
        @errors << "Table '#{table.name}': primary key references missing columns: #{missing.join(", ")}"
      end
    end

    def validate_indexes(table, column_names)
      table.indexes.each do |index|
        missing = index.column_names.reject { |col| column_names.include?(col) }
        if missing.any?
          @errors << "Table '#{table.name}': index '#{index.name}' references missing columns: #{missing.join(", ")}"
        end

        @errors << "Table '#{table.name}': index has empty name" if index.name.blank?
      end

      duplicates = table.indexes.map(&:name).tally.filter_map { |n, c| n if c > 1 }
      if duplicates.any?
        @errors << "Table '#{table.name}': duplicate index names: #{duplicates.join(", ")}"
      end
    end

    def validate_constraints(table)
      table.constraints.each do |constraint|
        @errors << "Table '#{table.name}': constraint has empty name" if constraint.name.blank?

        if constraint.condition.blank?
          @errors << "Table '#{table.name}': constraint '#{constraint.name}' has empty condition"
        end
      end
    end

    def validate_enum(enum)
      @errors << "Enum has empty name" if enum.name.blank?

      @errors << "Enum '#{enum.name}' has no values" if enum.values.empty?

      if %i[integer text].exclude?(enum.datatype)
        @errors << "Enum '#{enum.name}' has invalid datatype '#{enum.datatype}'"
      end

      expected_type = enum.datatype == :integer ? Integer : String
      invalid_values = enum.values.reject { |_, value| value.is_a?(expected_type) }
      if invalid_values.any?
        @errors << "Enum '#{enum.name}' has values that do not match datatype '#{enum.datatype}'"
      end
    end
  end
end
