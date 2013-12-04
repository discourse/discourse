module SiteSettings; end

class SiteSettings::YamlLoader

  def initialize(file)
    @file = file
  end

  def load
    yaml = YAML.load_file(@file)
    yaml.keys.each do |category|
      yaml[category].each do |setting_name, hash|
        if hash.is_a?(Hash)
          # Get default value for the site setting:
          value = hash.delete('default')

          # If there's a different default value for each environment, choose the right one:
          if value.is_a?(Hash)
            value = value.has_key?(Rails.env) ? value[Rails.env] : value['default']
          end

          yield category, setting_name, value, hash.symbolize_keys!
        else
          # Simplest case. site_setting_name: 'default value'
          yield category, setting_name, hash, {}
        end
      end
    end
  end
end