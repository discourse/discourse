require_dependency 'enum_site_setting'

class LocaleSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    supported_locales.include?(val)
  end

  def self.values
    supported_locales.map do |l|
      lang = language_names[l] || language_names[l[0..1]]
      { name: lang ? lang['nativeName'] : l, value: l }
    end
  end

  @lock = Mutex.new

  def self.language_names
    return @language_names if @language_names

    @lock.synchronize do
      @language_names ||= YAML.load(File.read(File.join(Rails.root, 'config', 'locales', 'names.yml')))
    end
  end

  def self.supported_locales
    @lock.synchronize do
      @supported_locales ||= begin
        app_client_files = Dir.glob(
          File.join(Rails.root, 'config', 'locales', 'client.*.yml')
        )

        plugin_client_files = Dir.glob(
          File.join(Rails.root, 'plugins', '*', 'config', 'locales', 'client.*.yml')
        )

        (app_client_files + plugin_client_files).map { |x| x.split('.')[-2] }.uniq.sort
      end
    end
  end

end
