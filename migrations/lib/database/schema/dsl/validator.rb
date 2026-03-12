# frozen_string_literal: true

module Migrations
  module Database
    module Schema
      module DSL
        class Validator
          def initialize(schema_module)
            @schema = schema_module
            @errors = []
          end

          def validate
            ActiveRecord::Base.with_connection do |connection|
              @db = connection
              @db_table_names = @db.tables.to_set
              @scope = ColumnScope.new(@schema)

              validate_configured_and_ignored_tables
              validate_tables
              validate_enums
              validate_stale_ignored_tables
            end

            @errors.freeze
          end

          private

          def validate_configured_and_ignored_tables
            ignored = @schema.ignored_tables
            return if ignored.nil?

            ignored_names = ignored.table_names

            # Synthetic tables don't use a DB source, so they can share a name with an ignored DB table
            configured_names =
              @schema.tables.each_value.filter_map { |t| t.name if t.source_table_name }.to_set

            overlap = configured_names & ignored_names
            overlap.sort.each { |name| @errors << "Table '#{name}' is both configured and ignored" }
          end

          def validate_tables
            configured_table_names =
              @schema.tables.each_value.filter_map(&:source_table_name).to_set
            ignored_table_names = @scope.ignored_table_name_set

            # Check for unconfigured tables in database
            unconfigured = @db_table_names - configured_table_names - ignored_table_names
            if unconfigured.any?
              @errors << "Tables exist in database but are not configured or ignored: #{sort_and_join(unconfigured)}"
            end

            # Validate each configured table
            @schema.tables.each_value { |table_def| validate_table(table_def) }
          end

          def validate_table(table_def)
            @table_def = table_def

            validate_ignored_plugin_source

            if @table_def.source_table_name
              source_table = @table_def.source_table_name

              if @db_table_names.exclude?(source_table)
                @errors << "Table '#{@table_def.name}': source table '#{source_table}' does not exist in database"
                return
              end

              @db_column_names = @db.columns(source_table).map(&:name).to_set
              @db_primary_keys = @db.primary_keys(source_table).map(&:to_s)
            else
              @db_column_names = Set.new
              @db_primary_keys = []
            end

            validate_included_columns
            validate_include_overrides
            validate_column_options
            validate_added_columns
            validate_ignored_columns
            validate_unconfigured_columns
            validate_primary_key_columns
            validate_index_columns
            validate_enum_references
          end

          def validate_included_columns
            return if @table_def.included_column_names.nil?

            missing = @table_def.included_column_names.to_set - @db_column_names
            if missing.any?
              @errors << "Table '#{@table_def.name}': included columns do not exist in database: #{sort_and_join(missing)}"
            end
          end

          def validate_include_overrides
            return if @table_def.included_column_names.nil?

            forced = @table_def.forced_column_names&.to_set || Set.new
            globally_ignored = @scope.globally_ignored_columns
            auto_ignored = auto_ignored_column_names

            @table_def.included_column_names.each do |col_name|
              next if forced.include?(col_name)

              if globally_ignored.include?(col_name)
                @errors << "Table '#{@table_def.name}': included column '#{col_name}' is globally ignored — use `include!` to override"
              elsif auto_ignored.include?(col_name)
                @errors << "Table '#{@table_def.name}': included column '#{col_name}' is auto-ignored by a plugin — use `include!` to override"
              end
            end
          end

          def validate_column_options
            configured_columns = @scope.effective_column_names(@table_def, @db_column_names)

            @table_def.column_options.each_key do |col_name|
              if @db_column_names.exclude?(col_name)
                @errors << "Table '#{@table_def.name}': column option for '#{col_name}' " \
                  "references a column that does not exist in database"
              elsif configured_columns.exclude?(col_name)
                @errors << "Table '#{@table_def.name}': column option for '#{col_name}' " \
                  "references an excluded column"
              end
            end
          end

          def validate_added_columns
            @table_def.added_columns.each do |added_col|
              if @db_column_names.include?(added_col.name)
                @errors << "Table '#{@table_def.name}': added column '#{added_col.name}' already exists in database"
              end

              if added_col.enum && !@schema.enums.key?(added_col.enum)
                @errors << "Table '#{@table_def.name}': added column '#{added_col.name}' references unknown enum '#{added_col.enum}'"
              end
            end
          end

          def validate_ignored_columns
            @table_def.ignored_columns_map.each_key do |col_name|
              if @db_column_names.exclude?(col_name)
                @errors << "Table '#{@table_def.name}': ignored column '#{col_name}' does not exist in database (stale ignore)"
              end
            end
          end

          def validate_index_columns
            configured_columns = @scope.effective_column_names(@table_def, @db_column_names)

            seen_names = {}
            @table_def.indexes.each do |idx|
              missing = idx.column_names.to_set - configured_columns
              if missing.any?
                index_message =
                  "Table '#{@table_def.name}': index '#{idx.name}' " \
                    "references columns not in configuration: #{sort_and_join(missing)}"
                @errors << index_message
              end

              name = idx.name
              if seen_names.key?(name)
                @errors << "Table '#{@table_def.name}': duplicate index name '#{name}'"
              else
                seen_names[name] = true
              end
            end
          end

          def validate_unconfigured_columns
            return if @table_def.source_table_name.nil?

            configured_columns = @scope.effective_column_names(@table_def, @db_column_names)
            ignored_columns = @table_def.ignored_column_names.to_set
            unconfigured =
              @db_column_names - configured_columns - ignored_columns -
                @scope.globally_ignored_columns - auto_ignored_column_names

            if unconfigured.any?
              @errors << "Table '#{@table_def.name}': database columns are not configured or ignored: #{sort_and_join(unconfigured)}"
            end
          end

          def validate_primary_key_columns
            configured_primary_keys = @table_def.primary_key_columns || @db_primary_keys
            return if configured_primary_keys.empty?

            if @table_def.source_table_name
              added_names = @table_def.added_columns.map(&:name).to_set
              missing_in_db = configured_primary_keys.to_set - @db_column_names - added_names
              if missing_in_db.any?
                pk_message =
                  "Table '#{@table_def.name}': primary key references columns " \
                    "that do not exist in database: #{sort_and_join(missing_in_db)}"
                @errors << pk_message
              end
            end

            configured_columns = @scope.effective_column_names(@table_def, @db_column_names)
            missing_in_config = configured_primary_keys.to_set - configured_columns
            if missing_in_config.any?
              @errors << "Table '#{@table_def.name}': primary key columns are not configured: #{sort_and_join(missing_in_config)}"
            end
          end

          def validate_enum_references
            @table_def.column_options.each do |col_name, options|
              type = options.type
              next if type.nil?
              next if known_type_override?(type)
              next if @schema.enums.key?(type)

              @errors << "Table '#{@table_def.name}': column '#{col_name}' type '#{type}' references unknown enum"
            end
          end

          def validate_ignored_plugin_source
            return if @table_def.source_table_name.nil?

            manifest = @schema.plugin_manifest
            return if !manifest.available?

            ignored = @schema.ignored_tables
            return if ignored.nil?

            plugin = manifest.plugin_for_table(@table_def.source_table_name)
            return if plugin.nil?

            if ignored.plugin_ignored?(plugin)
              @errors << "Table '#{@table_def.name}': source table '#{@table_def.source_table_name}' belongs to ignored plugin '#{plugin}'"
            end
          end

          def validate_enums
            @schema.enums.each_value do |enum_def|
              @errors << "Enum '#{enum_def.name}': has no values" if enum_def.values.empty?
            end
          end

          def validate_stale_ignored_tables
            ignored = @schema.ignored_tables
            return if ignored.nil?

            ignored.entries.each do |entry|
              if @db_table_names.exclude?(entry.name)
                @errors << "Ignored table '#{entry.name}' does not exist in database (stale ignore)"
              end
            end
          end

          def auto_ignored_column_names
            @scope.plugin_ignored_column_names(@table_def)
          end

          def sort_and_join(values)
            values.sort.join(", ")
          end

          def known_type_override?(type)
            Helpers::VALID_TYPE_OVERRIDES.include?(type)
          end
        end
      end
    end
  end
end
