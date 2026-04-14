# frozen_string_literal: true

module Migrations
  module Database
    module Schema
      module DSL
        class SchemaResolver
          def initialize(schema_module)
            @schema = schema_module
            @conventions = schema_module.conventions_config
            @enums_by_name = schema_module.enums.transform_values { |e| resolve_enum(e) }
            @scope = ColumnScope.new(@schema)
          end

          def resolve
            tables = resolve_tables
            enums = @enums_by_name.values

            Definition.new(tables:, enums:)
          end

          private

          def resolve_tables
            ActiveRecord::Base.with_connection do |connection|
              @db = connection
              @schema.tables.map { |_name, table_def| resolve_table(table_def) }
            end
          end

          def resolve_table(table_def)
            if table_def.source_table_name
              source_table = table_def.source_table_name
              db_columns = @db.columns(source_table).index_by(&:name)
              db_primary_keys = @db.primary_keys(source_table)
            else
              db_columns = {}
              db_primary_keys = []
            end

            primary_key_columns = table_def.primary_key_columns || db_primary_keys

            columns = resolve_included_columns(table_def, db_columns, primary_key_columns)
            columns += resolve_added_columns(table_def, primary_key_columns)

            indexes = resolve_indexes(table_def)
            constraints = resolve_constraints(table_def)

            # Map PK column names through renames, preserving the original order
            resolved_pk_names = resolve_primary_key_names(primary_key_columns, table_def, columns)

            TableDefinition.new(
              name: table_def.name,
              columns:,
              indexes:,
              primary_key_column_names: resolved_pk_names,
              constraints:,
              model_mode: table_def.model_mode,
            )
          end

          def resolve_included_columns(table_def, db_columns, primary_key_columns)
            column_names = determine_included_columns(table_def, db_columns)

            column_names.filter_map do |col_name|
              db_col = db_columns[col_name]
              next if db_col.nil?

              options = table_def.column_options_for(col_name)

              resolve_column(
                db_col,
                primary_key_columns:,
                type_override: options&.type,
                required_override: options&.required,
                max_length_override: options&.max_length,
                rename_to_override: options&.rename_to,
              )
            end
          end

          def determine_included_columns(table_def, db_columns)
            if table_def.included_column_names
              table_def.included_column_names
            else
              # nil means "all DB columns" minus globally ignored, per-table ignored, and plugin ignored
              all_names = db_columns.keys
              ignored = table_def.ignored_column_names.to_set
              globally_ignored = @conventions ? @conventions.ignored_columns.to_set : Set.new
              plugin_ignored = @scope.plugin_ignored_column_names(table_def)
              forced = table_def.forced_column_names&.to_set || Set.new
              all_names.reject do |n|
                ignored.include?(n) ||
                  (
                    (globally_ignored.include?(n) || plugin_ignored.include?(n)) &&
                      forced.exclude?(n)
                  )
              end
            end
          end

          def resolve_column(
            db_col,
            primary_key_columns:,
            type_override: nil,
            required_override: nil,
            max_length_override: nil,
            rename_to_override: nil
          )
            col_name = db_col.name
            convention = @conventions&.convention_for(col_name)

            effective_name = rename_to_override || convention&.rename_to || col_name

            raw_type = type_override || convention&.type_override || db_col.type

            datatype = normalize_datatype(raw_type)

            enum = nil
            if type_override && @enums_by_name.key?(type_override)
              enum = @enums_by_name[type_override]
              datatype = enum.datatype
            end

            required = required_override.nil? ? convention&.required : required_override

            # Columns with defaults are treated as nullable because converters
            # don't need to supply a value — the DB default will apply.
            nullable = required.nil? ? db_col.null || db_col.default.present? : !required

            max_length = (max_length_override || db_col.limit if datatype == :text)

            is_primary_key = primary_key_columns.include?(col_name)
            nullable = false if is_primary_key

            ColumnDefinition.new(
              name: effective_name,
              datatype:,
              nullable:,
              max_length:,
              is_primary_key:,
              enum:,
            )
          end

          def resolve_added_columns(table_def, primary_key_columns)
            table_def.added_columns.map do |added_col|
              effective_name = added_col.name

              enum = added_col.enum ? @enums_by_name[added_col.enum] : nil
              datatype = enum ? enum.datatype : added_col.type

              is_pk = primary_key_columns.include?(effective_name)

              ColumnDefinition.new(
                name: effective_name,
                datatype: normalize_datatype(datatype),
                nullable: is_pk ? false : !added_col.required,
                max_length: nil,
                is_primary_key: is_pk,
                enum:,
              )
            end
          end

          def resolve_primary_key_names(primary_key_columns, table_def, resolved_columns)
            resolved_column_names = resolved_columns.map(&:name).to_set

            primary_key_columns.filter_map do |pk_col|
              if table_def.source_table_name
                options = table_def.column_options_for(pk_col)
                rename_to = options&.rename_to
                resolved_name = rename_to || @conventions&.effective_name(pk_col) || pk_col
              else
                resolved_name = pk_col
              end
              resolved_name if resolved_column_names.include?(resolved_name)
            end
          end

          def resolve_indexes(table_def)
            table_def.indexes.map do |idx|
              resolved_columns =
                idx.column_names.map { |col_name| resolve_index_column_name(table_def, col_name) }

              IndexDefinition.new(
                name: idx.name,
                column_names: resolved_columns,
                unique: idx.unique,
                condition: idx.condition,
              )
            end
          end

          def resolve_index_column_name(table_def, col_name)
            return col_name if table_def.source_table_name.nil?

            options = table_def.column_options_for(col_name)
            options&.rename_to || @conventions&.effective_name(col_name) || col_name
          end

          def resolve_constraints(table_def)
            table_def.constraints.map do |constraint|
              ConstraintDefinition.new(
                name: constraint.name,
                type: constraint.type,
                condition: constraint.condition,
              )
            end
          end

          def resolve_enum(enum_def)
            EnumDefinition.new(
              name: enum_def.name,
              values: enum_def.values,
              datatype: enum_def.datatype,
            )
          end

          def normalize_datatype(type)
            type = type.to_sym
            Helpers::DATATYPE_ALIASES.fetch(type, type)
          end
        end
      end
    end
  end
end
