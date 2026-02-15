# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  class PluginManifest
    STALENESS_THRESHOLD = 24 * 60 * 60 # 24 hours

    def initialize(manifest_path:, plugins_path: nil)
      @manifest_path = manifest_path
      @plugins_path = plugins_path
      @data = nil
    end

    def fresh?
      return false unless File.exist?(@manifest_path)
      (Time.now - File.mtime(@manifest_path)) < STALENESS_THRESHOLD
    end

    def regenerate!
      introspector = PluginIntrospector.new(plugins_path: @plugins_path)
      @data = introspector.introspect
      FileUtils.mkdir_p(File.dirname(@manifest_path))
      File.write(@manifest_path, YAML.dump(@data))
      @data
    end

    def plugin_for_table(name)
      load_data
      @data.dig("tables", name.to_s)
    end

    def plugin_for_column(table, col)
      load_data
      @data.dig("columns", table.to_s, col.to_s)
    end

    def all_plugin_names
      load_data
      names = Set.new
      names.merge(@data["tables"].values) if @data["tables"]
      @data["columns"]&.each_value { |cols| names.merge(cols.values) }
      names.to_a.sort
    end

    def table_count
      load_data
      @data["tables"]&.size || 0
    end

    def column_count
      load_data
      @data["columns"]&.sum { |_, cols| cols.size } || 0
    end

    private

    def load_data
      return if @data
      if File.exist?(@manifest_path)
        @data = YAML.safe_load_file(@manifest_path) || { "tables" => {}, "columns" => {} }
      else
        @data = { "tables" => {}, "columns" => {} }
      end
    end
  end
end
