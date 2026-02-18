# frozen_string_literal: true

module Migrations::Database::Schema::DSL
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
      configured =
        @schema
          .tables
          .each_value
          .filter_map { |table_def| table_def.source_table_name&.to_s }
          .to_set
      ignored = ignored_table_name_set

      unconfigured = @db_table_names - configured - ignored
      unconfigured.sort.map { |name| TableInfo.new(name:, plugin: plugin_for_table(name)) }
    end

    def find_missing_tables
      missing = []

      @schema.tables.each_value do |table_def|
        next unless table_def.source_table_name

        source = table_def.source_table_name.to_s
        if @db_table_names.exclude?(source)
          missing << TableInfo.new(name: table_def.name.to_s, plugin: nil)
        end
      end

      missing.sort_by(&:name)
    end

    def find_stale_ignored_tables
      ignored = @schema.ignored_tables
      return [] unless ignored

      stale = []
      ignored.entries.each do |entry|
        if @db_table_names.exclude?(entry.name.to_s)
          stale << TableInfo.new(name: entry.name.to_s, plugin: nil)
        end
      end

      stale.sort_by(&:name)
    end

    def find_table_diffs
      diffs = []

      @schema.tables.each_value do |table_def|
        next unless table_def.source_table_name

        source = table_def.source_table_name.to_s
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

      configured_columns = effective_column_names

      auto_ignored = find_auto_ignored_columns
      unconfigured = find_unconfigured_columns(configured_columns, auto_ignored)
      missing = find_missing_columns
      stale = find_stale_ignored_columns

      has_changes = unconfigured.any? || missing.any? || stale.any? || auto_ignored.any?
      return nil unless has_changes

      TableDiff.new(
        table_name: @table_def.name.to_s,
        unconfigured_columns: unconfigured,
        missing_columns: missing,
        stale_ignored_columns: stale,
        auto_ignored_columns: auto_ignored,
      )
    end

    def find_unconfigured_columns(configured_columns, auto_ignored)
      ignored = @table_def.ignored_column_names.map(&:to_s).to_set
      globally_ignored = globally_ignored_columns
      auto_ignored_names = auto_ignored.map(&:name).to_set

      unconfigured =
        @db_column_names - configured_columns - ignored - globally_ignored - auto_ignored_names
      unconfigured.sort.map do |name|
        ColumnInfo.new(name:, plugin: plugin_for_column(@source_table, name))
      end
    end

    def find_missing_columns
      return [] unless @table_def.included_column_names

      missing = @table_def.included_column_names.map(&:to_s).to_set - @db_column_names
      missing.sort.map { |name| ColumnInfo.new(name:, plugin: nil) }
    end

    def find_stale_ignored_columns
      stale = []
      @table_def.ignored_columns_map.each_key do |col_name|
        if @db_column_names.exclude?(col_name.to_s)
          stale << ColumnInfo.new(name: col_name.to_s, plugin: nil)
        end
      end
      stale.sort_by(&:name)
    end

    def effective_column_names
      forced = @table_def.forced_column_names&.map(&:to_s)&.to_set || Set.new

      if @table_def.included_column_names
        names = @table_def.included_column_names.map(&:to_s).to_set
      else
        ignored = @table_def.ignored_column_names.map(&:to_s).to_set
        names = @db_column_names - ignored - (globally_ignored_columns - forced)
      end

      added = @table_def.added_columns.map { |c| c.name.to_s }
      names + added.to_set
    end

    def globally_ignored_columns
      @globally_ignored_columns ||=
        begin
          conventions = @schema.conventions_config
          return Set.new unless conventions
          conventions.ignored_columns.map(&:to_s).to_set
        end
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

    def find_auto_ignored_columns
      source_table = @table_def.source_table_name.to_s
      ignored = @schema.ignored_tables
      return [] unless ignored

      manifest = @schema.plugin_manifest
      return [] unless manifest.available?

      auto_ignored = []

      # Always auto-ignore columns from plugins listed in `plugin` declarations
      ignored.ignored_plugin_names.each do |plugin_name|
        cols = manifest.columns_for_plugin(plugin_name.to_s, table: source_table)
        cols.each { |col| auto_ignored << ColumnInfo.new(name: col, plugin: plugin_name.to_s) }
      end

      # ignore_plugin_columns! additionally ignores columns from non-ignored plugins
      if @table_def.ignore_plugin_columns?
        plugin_filter = @table_def.ignore_plugin_names&.map(&:to_s)&.to_set

        manifest.all_plugin_names.each do |plugin_name|
          next if ignored.plugin_ignored?(plugin_name)
          next if plugin_filter && plugin_filter.exclude?(plugin_name.to_s)
          cols = manifest.columns_for_plugin(plugin_name, table: source_table)
          cols.each { |col| auto_ignored << ColumnInfo.new(name: col, plugin: plugin_name) }
        end
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
