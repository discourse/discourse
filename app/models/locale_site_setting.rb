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

        unless ignore_plugins?
          app_client_files += Dir.glob(
            File.join(Rails.root, 'plugins', '*', 'config', 'locales', 'client.*.yml')
          )
        end

        app_client_files.map { |x| x.split('.')[-2] }
          .uniq
          .select { |locale| valid_locale?(locale) }
          .sort
      end
    end
  end

  def self.valid_locale?(locale)
    assets = Rails.configuration.assets

    assets.precompile.grep(/locales\/#{locale}(?:\.js)?/).present? &&
      (Dir.glob(File.join(Rails.root, 'app', 'assets', 'javascripts', 'locales', "#{locale}.js.erb")).present? ||
        Dir.glob(File.join(Rails.root, 'plugins', '*', 'assets', 'locales', "#{locale}.js.erb")).present?)
  end

  def self.ignore_plugins?
    Rails.env.test? && ENV['LOAD_PLUGINS'] != "1"
  end

  private_class_method :valid_locale?
  private_class_method :ignore_plugins?
end
