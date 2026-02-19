# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  class ColumnScope
    def initialize(schema)
      @schema = schema
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

    def globally_ignored_columns
      @globally_ignored_columns ||=
        begin
          conventions = @schema.conventions_config
          return Set.new unless conventions
          conventions.ignored_columns.map(&:to_s).to_set
        end
    end

    def effective_column_names(table_def, db_column_names)
      forced = table_def.forced_column_names&.map(&:to_s)&.to_set || Set.new

      if table_def.included_column_names
        names = table_def.included_column_names.map(&:to_s).to_set
      else
        ignored = table_def.ignored_column_names.map(&:to_s).to_set
        names = db_column_names - ignored - (globally_ignored_columns - forced)
      end

      added = table_def.added_columns.map { |c| c.name.to_s }
      names + added.to_set
    end

    def each_plugin_ignored_column(table_def)
      return unless table_def.source_table_name

      ignored = @schema.ignored_tables
      return unless ignored

      manifest = @schema.plugin_manifest
      return unless manifest.available?

      table_name = table_def.source_table_name.to_s

      ignored.ignored_plugin_names.each do |plugin_name|
        name = plugin_name.to_s
        manifest.columns_for_plugin(name, table: table_name).each { |col| yield col, name }
      end

      return unless table_def.ignore_plugin_columns?

      plugin_filter = table_def.ignore_plugin_names&.map(&:to_s)&.to_set

      manifest.all_plugin_names.each do |plugin_name|
        next if ignored.plugin_ignored?(plugin_name)
        name = plugin_name.to_s
        next if plugin_filter && plugin_filter.exclude?(name)
        manifest.columns_for_plugin(name, table: table_name).each { |col| yield col, name }
      end
    end
  end
end
