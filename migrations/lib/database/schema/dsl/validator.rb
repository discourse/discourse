# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  ValidationResult = Data.define(:errors, :warnings)

  class Validator
    def initialize(schema_module)
      @schema = schema_module
      @errors = []
      @warnings = []
    end

    def validate
      ActiveRecord::Base.with_connection do |connection|
        @db = connection
        @db_table_names = @db.tables.to_set

        validate_tables
        validate_enums
        validate_stale_ignored_tables
      end

      ValidationResult.new(errors: @errors.freeze, warnings: @warnings.freeze)
    end

    private

    def validate_tables
      configured_table_names = @schema.tables.keys.map(&:to_s).to_set
      ignored_table_names = ignored_table_name_set

      # Check for unconfigured tables in database
      unconfigured = @db_table_names - configured_table_names - ignored_table_names
      if unconfigured.any?
        @errors << "Tables exist in database but are not configured or ignored: #{sort_and_join(unconfigured)}"
      end

      # Validate each configured table
      @schema.tables.each_value { |table_def| validate_table(table_def) }
    end

    def validate_table(table_def)
      if table_def.source_table_name
        source_table = table_def.source_table_name.to_s

        if @db_table_names.exclude?(source_table)
          @errors << "Table '#{table_def.name}': source table '#{source_table}' does not exist in database"
          return
        end

        db_column_names = @db.columns(source_table).map(&:name).to_set
      else
        db_column_names = Set.new
      end

      validate_included_columns(table_def, db_column_names)
      validate_column_options(table_def, db_column_names)
      validate_added_columns(table_def, db_column_names)
      validate_ignored_columns(table_def, db_column_names)
      validate_index_columns(table_def, db_column_names)
      validate_enum_references(table_def)
    end

    def validate_included_columns(table_def, db_column_names)
      return unless table_def.included_column_names

      missing = table_def.included_column_names.map(&:to_s).to_set - db_column_names
      if missing.any?
        @errors << "Table '#{table_def.name}': included columns do not exist in database: #{sort_and_join(missing)}"
      end
    end

    def validate_column_options(table_def, db_column_names)
      table_def.column_options.each_key do |col_name|
        if db_column_names.exclude?(col_name.to_s)
          @errors << "Table '#{table_def.name}': column option for '#{col_name}' references a column that does not exist in database"
        end
      end
    end

    def validate_added_columns(table_def, db_column_names)
      table_def.added_columns.each do |added_col|
        if db_column_names.include?(added_col.name.to_s)
          @errors << "Table '#{table_def.name}': added column '#{added_col.name}' already exists in database"
        end

        if added_col.enum && !@schema.enums.key?(added_col.enum)
          @errors << "Table '#{table_def.name}': added column '#{added_col.name}' references unknown enum '#{added_col.enum}'"
        end
      end
    end

    def validate_ignored_columns(table_def, db_column_names)
      table_def.ignored_columns_map.each_key do |col_name|
        if db_column_names.exclude?(col_name.to_s)
          @warnings << "Table '#{table_def.name}': ignored column '#{col_name}' does not exist in database (stale ignore)"
        end
      end
    end

    def validate_index_columns(table_def, db_column_names)
      configured_columns = effective_column_names(table_def, db_column_names)

      table_def.indexes.each do |idx|
        missing = idx.column_names.map(&:to_s).to_set - configured_columns
        if missing.any?
          @errors << "Table '#{table_def.name}': index '#{idx.name}' references columns not in configuration: #{sort_and_join(missing)}"
        end
      end
    end

    def validate_enum_references(table_def)
      table_def.column_options.each do |col_name, options|
        next unless options.type
        if @schema.enums.key?(options.type)
          # valid enum reference — ok
        end
      end
    end

    def validate_enums
      @schema.enums.each_value do |enum_def|
        @errors << "Enum '#{enum_def.name}': has no values" if enum_def.values.empty?
      end
    end

    def validate_stale_ignored_tables
      ignored = @schema.ignored_tables
      return unless ignored

      ignored.entries.each do |entry|
        if @db_table_names.exclude?(entry.name.to_s)
          @warnings << "Ignored table '#{entry.name}' does not exist in database (stale ignore)"
        end
      end
    end

    def effective_column_names(table_def, db_column_names)
      if table_def.included_column_names
        names = table_def.included_column_names.map(&:to_s).to_set
      else
        ignored = table_def.ignored_column_names.map(&:to_s).to_set
        globally_ignored = globally_ignored_columns
        names = db_column_names - ignored - globally_ignored
      end

      added = table_def.added_columns.map { |c| c.name.to_s }
      names + added.to_set
    end

    def globally_ignored_columns
      conventions = @schema.conventions_config
      return Set.new unless conventions
      conventions.ignored_columns.map(&:to_s).to_set
    end

    def ignored_table_name_set
      ignored = @schema.ignored_tables
      return Set.new unless ignored
      ignored.table_names.map(&:to_s).to_set
    end

    def sort_and_join(values)
      values.sort.join(", ")
    end
  end
end
