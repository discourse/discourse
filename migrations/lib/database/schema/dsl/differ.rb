# frozen_string_literal: true

module Migrations
  module Database
    module Schema
      module DSL
        TableInfo = Data.define(:name, :plugin)
        ColumnInfo = Data.define(:name, :plugin)
        TableDiff =
          Data.define(
            :table_name,
            :unconfigured_columns,
            :missing_columns,
            :stale_ignored_columns,
            :auto_ignored_columns,
          )
        DiffResult =
          Data.define(:unconfigured_tables, :missing_tables, :stale_ignored_tables, :table_diffs)

        class Differ
          def initialize(schema_module)
            @schema = schema_module
          end

          def diff
            ActiveRecord::Base.with_connection do |connection|
              @db = connection
              @db_table_names = @db.tables.to_set
              @scope = ColumnScope.new(@schema)

              unconfigured_tables = find_unconfigured_tables
              missing_tables = find_missing_tables
              stale_ignored = find_stale_ignored_tables
              table_diffs = find_table_diffs

              DiffResult.new(
                unconfigured_tables:,
                missing_tables:,
                stale_ignored_tables: stale_ignored,
                table_diffs:,
              )
            end
          end

          private

          def find_unconfigured_tables
            configured = @schema.tables.each_value.filter_map(&:source_table_name).to_set
            ignored = @scope.ignored_table_name_set

            unconfigured = @db_table_names - configured - ignored
            unconfigured.sort.map { |name| TableInfo.new(name:, plugin: plugin_for_table(name)) }
          end

          def find_missing_tables
            missing = []

            @schema.tables.each_value do |table_def|
              next if table_def.source_table_name.nil?

              source = table_def.source_table_name
              if @db_table_names.exclude?(source)
                missing << TableInfo.new(name: table_def.name, plugin: nil)
              end
            end

            missing.sort_by(&:name)
          end

          def find_stale_ignored_tables
            ignored = @schema.ignored_tables
            return [] if ignored.nil?

            stale = []
            ignored.entries.each do |entry|
              if @db_table_names.exclude?(entry.name)
                stale << TableInfo.new(name: entry.name, plugin: nil)
              end
            end

            stale.sort_by(&:name)
          end

          def find_table_diffs
            diffs = []

            @schema.tables.each_value do |table_def|
              next if table_def.source_table_name.nil?

              source = table_def.source_table_name
              next if @db_table_names.exclude?(source)

              table_diff = diff_table(table_def, source)
              diffs << table_diff if table_diff
            end

            diffs.sort_by(&:table_name)
          end

          def diff_table(table_def, source_table)
            @table_def = table_def
            @db_column_names = @db.columns(source_table).map(&:name).to_set
            @source_table = source_table

            configured_columns = @scope.effective_column_names(@table_def, @db_column_names)

            auto_ignored = find_auto_ignored_columns
            unconfigured = find_unconfigured_columns(configured_columns, auto_ignored)
            missing = find_missing_columns
            stale = find_stale_ignored_columns

            has_changes = unconfigured.any? || missing.any? || stale.any? || auto_ignored.any?
            return nil if !has_changes

            TableDiff.new(
              table_name: @table_def.name,
              unconfigured_columns: unconfigured,
              missing_columns: missing,
              stale_ignored_columns: stale,
              auto_ignored_columns: auto_ignored,
            )
          end

          def find_unconfigured_columns(configured_columns, auto_ignored)
            ignored = @table_def.ignored_column_names.to_set
            globally_ignored = @scope.globally_ignored_columns
            auto_ignored_names = auto_ignored.map(&:name).to_set

            unconfigured =
              @db_column_names - configured_columns - ignored - globally_ignored -
                auto_ignored_names
            unconfigured.sort.map do |name|
              ColumnInfo.new(name:, plugin: plugin_for_column(@source_table, name))
            end
          end

          def find_missing_columns
            return [] if @table_def.included_column_names.nil?

            missing = @table_def.included_column_names.to_set - @db_column_names
            missing.sort.map { |name| ColumnInfo.new(name:, plugin: nil) }
          end

          def find_stale_ignored_columns
            stale = []
            @table_def.ignored_columns_map.each_key do |col_name|
              if @db_column_names.exclude?(col_name)
                stale << ColumnInfo.new(name: col_name, plugin: nil)
              end
            end
            stale.sort_by(&:name)
          end

          def find_auto_ignored_columns
            auto_ignored = []
            @scope.each_plugin_ignored_column(@table_def) do |col, plugin|
              auto_ignored << ColumnInfo.new(name: col, plugin:)
            end
            auto_ignored.uniq(&:name).sort_by(&:name)
          end

          def plugin_for_table(name)
            manifest = @schema.plugin_manifest
            manifest.available? ? manifest.plugin_for_table(name) : nil
          end

          def plugin_for_column(table_name, col_name)
            manifest = @schema.plugin_manifest
            manifest.available? ? manifest.plugin_for_column(table_name, col_name) : nil
          end
        end
      end
    end
  end
end
