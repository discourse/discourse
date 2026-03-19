# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  class PluginManifest
    def initialize(manifest_path:, plugins_path: nil)
      @manifest_path = manifest_path
      @plugins_path = plugins_path || File.join(Rails.root, "plugins")

      @data = YAML.safe_load_file(@manifest_path) if available?
      @data ||= empty_data

      @table_to_plugin = nil
      @column_to_plugin = nil
    end

    def fresh?
      return false if !available?

      stored_checksums = @data["plugin_checksums"]
      return false if !stored_checksums

      stored_checksums == PluginIntrospector.compute_checksums(@plugins_path)
    end

    def available?
      File.exist?(@manifest_path)
    end

    def incomplete?
      failed_plugins.any?
    end

    def regenerate!
      introspector = PluginIntrospector.new(plugins_path: @plugins_path)
      result = introspector.introspect

      should_write = !available? || @data != result
      @data = result

      if should_write
        FileUtils.mkdir_p(File.dirname(@manifest_path))
        File.write(@manifest_path, format_yaml(@data))
      end

      @table_to_plugin = nil
      @column_to_plugin = nil
    end

    def plugin_for_table(name)
      build_reverse_indexes
      @table_to_plugin[name.to_s]
    end

    def plugin_for_column(table, col)
      build_reverse_indexes
      @column_to_plugin.dig(table.to_s, col.to_s)
    end

    def all_plugin_names
      plugins = @data["plugins"] || {}
      plugins.keys.sort
    end

    def tables_for_plugin(name)
      @data.dig("plugins", normalize_plugin_name(name), "tables") || []
    end

    def columns_for_plugin(name, table: nil)
      plugin_data = @data.dig("plugins", normalize_plugin_name(name), "columns") || {}
      if table
        plugin_data[table.to_s] || []
      else
        plugin_data
      end
    end

    def table_count
      plugins = @data["plugins"] || {}
      plugins.sum { |_, data| (data["tables"] || []).size }
    end

    def column_count
      plugins = @data["plugins"] || {}
      plugins.sum { |_, data| (data["columns"] || {}).sum { |_, cols| cols.size } }
    end

    def failed_plugins
      Array(@data["failed_plugins"])
    end

    private

    def normalize_plugin_name(name)
      ::Migrations::Database::Schema::Helpers.normalize_plugin_name(name)
    end

    def empty_data
      { "plugins" => {}, "plugin_checksums" => {}, "failed_plugins" => [], "incomplete" => false }
    end

    def format_yaml(data)
      YAML.dump(data, indentation: 2).sub(/\A---\n/, "").gsub(/^(\s*)-/, '\1  -')
    end

    def build_reverse_indexes
      return if @table_to_plugin

      @table_to_plugin = {}
      @column_to_plugin = {}

      plugins = @data["plugins"] || {}
      plugins.each do |plugin_name, plugin_data|
        (plugin_data["tables"] || []).each { |t| @table_to_plugin[t] = plugin_name }

        (plugin_data["columns"] || {}).each do |table, cols|
          @column_to_plugin[table] ||= {}
          cols.each { |col| @column_to_plugin[table][col] = plugin_name }
        end
      end
    end
  end
end
