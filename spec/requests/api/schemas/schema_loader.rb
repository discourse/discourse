# frozen_string_literal: true

require "json"

module SpecSchemas
  class SpecLoader
    def initialize(filename)
      @filename = filename
    end

    def load
      path = find_schema_file
      raise "Schema file not found: #{@filename}.json" unless path

      JSON.parse(File.read(path))
    end

    private

    def find_schema_file
      # Search plugin directories first
      plugin_paths =
        Dir.glob(Rails.root.join("plugins/*/spec/requests/api/schemas/json/#{@filename}.json"))
      return plugin_paths.first if plugin_paths.any?

      # Fall back to core
      core_path = File.join(__dir__, "json", "#{@filename}.json")
      File.exist?(core_path) ? core_path : nil
    end
  end
end
