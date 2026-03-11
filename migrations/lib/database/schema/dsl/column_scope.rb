# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  class ColumnScope
    def initialize(schema)
      @schema = schema
    end

    def ignored_table_name_set
      ignored = @schema.ignored_tables
      return Set.new if ignored.nil?

      names = ignored.table_names

      manifest = @schema.plugin_manifest
      if manifest.available?
        ignored.ignored_plugin_names.each do |plugin_name|
          manifest.tables_for_plugin(plugin_name).each { |t| names << t }
        end
      end

      names
    end

    def globally_ignored_columns
      @globally_ignored_columns ||=
        begin
          conventions = @schema.conventions_config
          return Set.new if conventions.nil?
          conventions.ignored_columns.to_set
        end
    end

    def effective_column_names(table_def, db_column_names)
      forced = table_def.forced_column_names&.to_set || Set.new

      if table_def.included_column_names
        names = table_def.included_column_names.to_set
      else
        ignored = table_def.ignored_column_names.to_set
        auto_ignored = (globally_ignored_columns | plugin_ignored_column_names(table_def)) - forced
        names = db_column_names - ignored - auto_ignored
      end

      added = table_def.added_columns.map(&:name)
      names + added.to_set
    end

    def plugin_ignored_column_names(table_def)
      names = Set.new
      each_plugin_ignored_column(table_def) { |col, _| names << col }
      names
    end

    def each_plugin_ignored_column(table_def, &block)
      return if table_def.source_table_name.nil?

      ignored = @schema.ignored_tables
      return if ignored.nil?

      manifest = @schema.plugin_manifest
      return if !manifest.available?

      table_name = table_def.source_table_name

      yield_columns_from_ignored_plugins(manifest, ignored, table_name, &block)
      yield_columns_from_table_plugins(manifest, ignored, table_def, table_name, &block)
    end

    private

    def yield_columns_from_ignored_plugins(manifest, ignored, table_name, &)
      ignored.ignored_plugin_names.each do |plugin_name|
        manifest
          .columns_for_plugin(plugin_name, table: table_name)
          .each { |col| yield col, plugin_name }
      end
    end

    def yield_columns_from_table_plugins(manifest, ignored, table_def, table_name, &)
      return if !table_def.ignore_plugin_columns?

      plugin_filter = table_def.ignore_plugin_names&.to_set

      manifest.all_plugin_names.each do |plugin_name|
        next if ignored.plugin_ignored?(plugin_name)
        next if plugin_filter && plugin_filter.exclude?(plugin_name)
        manifest
          .columns_for_plugin(plugin_name, table: table_name)
          .each { |col| yield col, plugin_name }
      end
    end
  end
end
