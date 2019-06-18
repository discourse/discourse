# frozen_string_literal: true

module SiteSettings; end

class SiteSettings::YamlLoader
  def initialize(file)
    @file = file
  end

  def load
    yaml = YAML.load_file(@file)
    yaml.each_key do |category|
      yaml[category].each do |setting_name, hash|
        if hash.is_a?(Hash)
          # Get default value for the site setting:
          value = hash.delete('default')

          if value.is_a?(Hash)
            raise Discourse::Deprecation, "The site setting `#{setting_name}` can no longer be set based on Rails environment. See also `config/environments/<env>.rb`."
          elsif value.nil?
            raise StandardError, "The site setting `#{setting_name}` in '#{@file}' is missing default value."
          end

          if hash['hidden']&.is_a?(Hash)
            raise Discourse::Deprecation, "The site setting `#{setting_name}`'s hidden property can no longer be set based on Rails environment. It can only be either `true` or `false`."
          end

          yield category, setting_name, value, hash.deep_symbolize_keys!
        else
          # Simplest case. site_setting_name: 'default value'
          yield category, setting_name, hash, {}
        end
      end
    end
  end
end
