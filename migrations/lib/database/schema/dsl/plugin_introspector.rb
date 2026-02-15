# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  class PluginIntrospector
    CREATE_TABLE_REGEX = /create_table\s+[:"'](\w+)/
    ADD_COLUMN_REGEX = /add_column\s+[:"'](\w+)[,"'\s]+[:"'](\w+)/

    def initialize(plugins_path: nil)
      @plugins_path = plugins_path || File.join(Rails.root, "plugins")
    end

    def introspect
      tables = {}
      columns = {}

      Dir[File.join(@plugins_path, "*")].sort.each do |plugin_dir|
        next unless File.directory?(plugin_dir)

        plugin_name = File.basename(plugin_dir)
        migrations_dir = File.join(plugin_dir, "db", "migrate")
        next unless File.directory?(migrations_dir)

        Dir[File.join(migrations_dir, "*.rb")].each do |migration_file|
          content = File.read(migration_file)

          content
            .scan(CREATE_TABLE_REGEX)
            .each do |match|
              table_name = match[0]
              tables[table_name] = plugin_name
            end

          content
            .scan(ADD_COLUMN_REGEX)
            .each do |match|
              table_name = match[0]
              column_name = match[1]
              columns[table_name] ||= {}
              columns[table_name][column_name] = plugin_name
            end
        end
      end

      { "tables" => tables, "columns" => columns }
    end
  end
end
