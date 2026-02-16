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
        db_primary_keys = @db.primary_keys(source_table).map(&:to_s)
      else
        db_column_names = Set.new
        db_primary_keys = []
      end

      validate_included_columns(table_def, db_column_names)
      validate_column_options(table_def, db_column_names)
      validate_added_columns(table_def, db_column_names)
      validate_ignored_columns(table_def, db_column_names)
      validate_unknown_columns(table_def, db_column_names)
      validate_primary_key_columns(table_def, db_column_names, db_primary_keys)
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
          missing_column_message =
            "Table '#{table_def.name}': column option for '#{col_name}' " \
              "references a column that does not exist in database"
          @errors << missing_column_message
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
          index_message =
            "Table '#{table_def.name}': index '#{idx.name}' " \
              "references columns not in configuration: #{sort_and_join(missing)}"
          @errors << index_message
        end
      end
    end

    def validate_unknown_columns(table_def, db_column_names)
      return unless table_def.source_table_name

      configured_columns = effective_column_names(table_def, db_column_names)
      ignored_columns = table_def.ignored_column_names.map(&:to_s).to_set
      unknown =
        db_column_names - configured_columns - ignored_columns - globally_ignored_columns -
          auto_ignored_column_names(table_def)

      if unknown.any?
        @errors << "Table '#{table_def.name}': database columns are not configured or ignored: #{sort_and_join(unknown)}"
      end
    end

    def validate_primary_key_columns(table_def, db_column_names, db_primary_keys)
      configured_primary_keys = table_def.primary_key_columns&.map(&:to_s) || db_primary_keys
      return if configured_primary_keys.empty?

      if table_def.source_table_name
        added_names = table_def.added_columns.map { |c| c.name.to_s }.to_set
        missing_in_db = configured_primary_keys.to_set - db_column_names - added_names
        if missing_in_db.any?
          pk_message =
            "Table '#{table_def.name}': primary key references columns " \
              "that do not exist in database: #{sort_and_join(missing_in_db)}"
          @errors << pk_message
        end
      end

      configured_columns = effective_column_names(table_def, db_column_names)
      missing_in_config = configured_primary_keys.to_set - configured_columns
      if missing_in_config.any?
        @errors << "Table '#{table_def.name}': primary key columns are not configured: #{sort_and_join(missing_in_config)}"
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

      names = ignored.table_names.map(&:to_s).to_set

      manifest = @schema.plugin_manifest
      if manifest.available?
        ignored.ignored_plugin_names.each do |plugin_name|
          manifest.tables_for_plugin(plugin_name.to_s).each { |t| names << t.to_s }
        end
      end

      names
    end

    def auto_ignored_column_names(table_def)
      return Set.new unless table_def.source_table_name

      ignored = @schema.ignored_tables
      return Set.new unless ignored

      manifest = @schema.plugin_manifest
      return Set.new unless manifest.available?

      table_name = table_def.source_table_name.to_s
      names = Set.new

      ignored.ignored_plugin_names.each do |plugin_name|
        manifest
          .columns_for_plugin(plugin_name.to_s, table: table_name)
          .each { |column_name| names << column_name.to_s }
      end

      if table_def.ignore_plugin_columns?
        manifest.all_plugin_names.each do |plugin_name|
          next if ignored.plugin_ignored?(plugin_name.to_sym)

          manifest
            .columns_for_plugin(plugin_name, table: table_name)
            .each { |column_name| names << column_name.to_s }
        end
      end

      names
    end

    def sort_and_join(values)
      values.sort.join(", ")
    end
  end
end
