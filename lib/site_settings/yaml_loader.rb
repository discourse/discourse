# frozen_string_literal: true

module SiteSettings
end

class SiteSettings::YamlLoader
  def initialize(file)
    @file = file
  end

  def load
    yaml = load_yaml(@file)
    yaml.each_key do |category|
      yaml[category].each do |setting_name, hash|
        if hash.is_a?(Hash)
          # Get default value for the site setting:
          value = hash.delete("default")

          if value.nil?
            raise StandardError,
                  "The site setting `#{setting_name}` in '#{@file}' is missing default value."
          end

          if hash.values_at("min", "max").any? && hash["validator"].present?
            raise StandardError,
                  "The site setting `#{setting_name}` in '#{@file}' will have it's min/max validation ignored because there is a validator also specified."
          end

          yield category, setting_name, value, hash.deep_symbolize_keys!
        else
          # Simplest case. site_setting_name: 'default value'
          yield category, setting_name, hash, {}
        end
      end
    end
  end

  private

  def load_yaml(path)
    YAML.load_file(path, aliases: true)
  end
end
