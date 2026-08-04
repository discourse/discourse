# frozen_string_literal: true

module Migrations
  class SettingsParser
    class InvalidYaml < StandardError
    end
    class ValidationError < StandardError
    end

    REQUIRED_KEYS = %i[intermediate_db root_paths]

    # Keys that used to live in the settings file and now come from CLI flags
    # only. A leftover key here is almost certainly a stale config, so we point
    # the user at the flag instead of silently ignoring it.
    REMOVED_KEYS = { fix_missing: "--fix-missing", create_optimized_images: "--optimize" }.freeze

    def initialize(options)
      @options = options

      validate!
      apply_defaults
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
      validate_removed_keys
      validate_paths
    end

    def validate_required_keys
      missing = REQUIRED_KEYS - @options.keys

      raise ValidationError, "Missing required keys: #{missing.join(", ")}" if missing.any?
    end

    def validate_removed_keys
      REMOVED_KEYS.each do |key, flag|
        next unless @options.key?(key)

        raise ValidationError,
              "`#{key}` has moved to the #{flag} flag; remove it from the settings file."
      end
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

    # Both files live next to the IntermediateDB by default; either can still be
    # set explicitly in the settings file. Deriving them here means the rest of
    # the run reads final values and never has to fall back to a default.
    def apply_defaults
      intermediate_db = @options[:intermediate_db]

      @options[:files_db] ||= CompanionPaths.files_db(intermediate_db)
      @options[:download_cache_path] ||= CompanionPaths.download_cache_path(intermediate_db)
    end
  end
end
