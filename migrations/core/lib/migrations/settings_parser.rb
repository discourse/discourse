# frozen_string_literal: true

module Migrations
  class SettingsParser
    class InvalidYaml < StandardError
    end
    class ValidationError < StandardError
    end

    REQUIRED_KEYS = %i[intermediate_db files_db root_paths]

    def initialize(options)
      @options = options

      validate!
    end

    def [](key)
      @options[key]
    end

    def []=(key, value)
      @options[key] = value
    end

    def fetch(key, default)
      @options.fetch(key, default)
    end

    def self.parse!(path)
      new(YAML.load_file(path, symbolize_names: true))
    rescue Psych::SyntaxError => e
      raise InvalidYaml.new(e.message)
    end

    private

    def validate!
      validate_required_keys
      validate_paths
    end

    def validate_required_keys
      missing = REQUIRED_KEYS - @options.keys

      raise ValidationError, "Missing required keys: #{missing.join(", ")}" if missing.any?
    end

    def validate_paths
      %i[intermediate_db files_db].each do |key|
        path = @options[key]

        next unless path

        dir = File.dirname(path)
        raise ValidationError, "Directory not writable: #{dir}" unless File.writable?(dir)
      end

      if !@options[:root_paths].is_a?(Array)
        raise ValidationError, "Root paths must be an array of paths"
      end

      @options[:root_paths].each do |path|
        raise ValidationError, "Directory not readable: #{path}" unless File.readable?(path)
      end
    end
  end
end
