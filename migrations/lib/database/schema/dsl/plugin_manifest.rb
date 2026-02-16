# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  class PluginManifest
    def initialize(manifest_path:, plugins_path: nil)
      @manifest_path = manifest_path
      @plugins_path = plugins_path
      @data = nil
      @table_to_plugin = nil
      @column_to_plugin = nil
    end

    def fresh?
      return false unless File.exist?(@manifest_path)

      load_data
      stored_state = @data["migration_state"]
      return false unless stored_state

      introspector = build_introspector
      current = introspector.compute_all_checksums

      return false unless stored_state["core"] == current["core"]

      stored_plugins = stored_state["plugins"] || {}
      current_plugins = current["plugins"] || {}

      stored_plugins == current_plugins
    end

    def available?
      File.exist?(@manifest_path)
    end

    def regenerate!
      introspector = build_introspector
      result = introspector.introspect

      @data = { "generated_at" => Time.now.utc.iso8601 }.merge(result)
      @table_to_plugin = nil
      @column_to_plugin = nil

      FileUtils.mkdir_p(File.dirname(@manifest_path))
      File.write(@manifest_path, format_yaml(@data))
      @data
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
      load_data
      plugins = @data["plugins"] || {}
      plugins.keys.sort
    end

    def tables_for_plugin(name)
      load_data
      @data.dig("plugins", normalize_plugin_name(name), "tables") || []
    end

    def columns_for_plugin(name, table: nil)
      load_data
      plugin_data = @data.dig("plugins", normalize_plugin_name(name), "columns") || {}
      if table
        plugin_data[table.to_s] || []
      else
        plugin_data
      end
    end

    def table_count
      load_data
      plugins = @data["plugins"] || {}
      plugins.sum { |_, data| (data["tables"] || []).size }
    end

    def column_count
      load_data
      plugins = @data["plugins"] || {}
      plugins.sum { |_, data| (data["columns"] || {}).sum { |_, cols| cols.size } }
    end

    private

    # Plugin directory names use hyphens (discourse-ai), but Ruby symbols
    # use underscores (discourse_ai). Normalize for manifest lookups.
    def normalize_plugin_name(name)
      name.to_s.tr("_", "-")
    end

    def build_introspector
      PluginIntrospector.new(plugins_path: @plugins_path)
    end

    def load_data
      return if @data
      if File.exist?(@manifest_path)
        @data = YAML.safe_load_file(@manifest_path) || empty_data
      else
        @data = empty_data
      end
    end

    def empty_data
      { "plugins" => {}, "migration_state" => { "core" => nil, "plugins" => {} } }
    end

    def format_yaml(data)
      yaml = YAML.dump(data).sub(/\A---\n/, "")

      yaml.gsub(/^(( *)\S.*:\n)((\2- .*\n)+)/) do
        key_line = $1
        indent = $2
        items = $3.gsub(/^#{Regexp.escape(indent)}-/, "#{indent}  -")
        "#{key_line}#{items}"
      end
    end

    def build_reverse_indexes
      return if @table_to_plugin

      load_data
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
