# frozen_string_literal: true

module Migrations
  class SettingsParser
    class InvalidYaml < StandardError
    end

    class ValidationError < StandardError
    end

    REQUIRED_KEYS = %i[intermediate_db root_paths]

    # Keys that are not supported in the settings file. Each one fails the
    # validation with a message that says what to do, so a setting that would
    # have no effect is not accepted without a word.
    REMOVED_KEYS = {
      fix_missing: "has moved to the --fix-missing flag",
      create_optimized_images: "has moved to the --optimize flag",
      thread_count_factor: "is not used anymore, the number of workers now adjusts itself",
    }.freeze

    REMOVED_SITE_SETTINGS = {
      authorized_extensions: "is not used anymore, all extensions are allowed",
      max_attachment_size_kb: "is not used anymore, the limit is always 100 MB",
      max_image_size_kb: "is not used anymore, the limit is always 100 MB",
      max_image_megapixels: "is not used anymore, the limit is always 150 megapixels",
    }.freeze

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
      REMOVED_KEYS.each do |key, reason|
        raise_removed_key("`#{key}`", reason) if @options.key?(key)
      end

      site_settings = @options[:site_settings]
      return unless site_settings.is_a?(Hash)

      REMOVED_SITE_SETTINGS.each do |key, reason|
        raise_removed_key("`site_settings.#{key}`", reason) if site_settings.key?(key)
      end
    end

    def raise_removed_key(name, reason)
      raise ValidationError, "#{name} #{reason}; remove it from the settings file."
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

    # Both paths can be set in the settings file. Otherwise they are derived from
    # the IntermediateDB path here, so the rest of the run only reads final
    # values.
    def apply_defaults
      intermediate_db = @options[:intermediate_db]

      @options[:files_db] ||= CompanionPaths.files_db(intermediate_db)
      @options[:download_cache_path] ||= CompanionPaths.download_cache_path(intermediate_db)
    end
  end
end
