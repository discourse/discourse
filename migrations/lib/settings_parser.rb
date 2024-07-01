# frozen_string_literal: true

module Migrations
  class SettingsParser
    class InvalidYaml < StandardError
    end

    def initialize(options)
      @options = options
    end

    # TODO: Compare against dynamically defining getters for
    #       each top-level setting
    def [](key)
      @options[key]
    end

    def []=(key, value)
      @options[key] = value
    end

    def self.parse!(path)
      new(YAML.load_file(path, symbolize_names: true))
    rescue Psych::SyntaxError => e
      raise InvalidYaml.new(e.message)
    end
  end
end
