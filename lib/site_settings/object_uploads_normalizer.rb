# frozen_string_literal: true

# TODO(gabriel): This was added as a fix for a bug in `type: object` settings.
# This is only used by a rake task. This class can be removed by May 2027

module SiteSettings
  class ObjectUploadsNormalizer
    def initialize(dry_run: false, output: $stdout)
      @dry_run = dry_run
      @output = output
      @counts = Hash.new(0)
    end

    def normalize
      normalize_site_settings
      normalize_theme_settings

      SiteSetting.refresh!
      Theme.expire_site_setting_cache!

      @counts
    end

    private

    def normalize_site_settings
      SiteSetting
        .where(data_type: SiteSettings::TypeSupervisor.types[:objects])
        .find_each do |setting|
          normalize_json_setting(
            setting,
            schema: site_setting_schema(setting.name),
            value: setting.value,
            label: "site setting #{setting.name}",
          ) { |normalized| setting.update!(value: JSON.generate(normalized)) }
        end
    end

    def normalize_theme_settings
      ThemeSetting
        .where(data_type: ThemeSetting.types[:objects])
        .includes(:theme)
        .find_each do |setting|
          normalize_json_setting(
            setting,
            schema: theme_setting_schema(setting),
            value: setting.json_value,
            label: "theme setting #{setting.theme.name}:#{setting.name}",
          ) { |normalized| setting.update!(json_value: normalized) }
        end
    end

    def normalize_json_setting(record, schema:, value:, label:)
      @counts[:processed] += 1

      if schema.blank?
        @counts[:skipped] += 1
        @output.puts("Skipping #{label}: schema not found")
        return
      end

      objects = parse_objects(value)
      if !objects.is_a?(Array)
        @counts[:invalid_json] += 1
        @output.puts("Skipping #{label}: value is not an objects array")
        return
      end

      normalized_objects = SchemaSettingsObjectValidator.normalize_uploads(schema:, objects:)

      if normalized_objects == objects
        @counts[:unchanged] += 1
        return
      end

      @counts[:changed] += 1
      @output.puts("#{@dry_run ? "Would normalize" : "Normalizing"} #{label}")
      yield normalized_objects if !@dry_run
    rescue JSON::ParserError
      @counts[:invalid_json] += 1
      @output.puts("Skipping #{label}: invalid JSON")
    rescue => error
      @counts[:errors] += 1
      @output.puts("Failed #{label}: #{error.class}: #{error.message}")
    end

    def parse_objects(value)
      value.is_a?(String) ? JSON.parse(value) : value
    end

    def site_setting_schema(name)
      SiteSetting.type_supervisor.type_hash(name.to_sym)[:schema]
    end

    def theme_setting_schema(setting)
      setting.theme.settings[setting.name.to_sym]&.schema
    end
  end
end
