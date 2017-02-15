require_dependency 'enum_site_setting'

class LocaleSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    supported_locales.include?(val)
  end

  def self.values
    supported_locales.map do |l|
      lang = language_names[l] || language_names[l[0..1]]
      {name: lang ? lang['nativeName'] : l, value: l}
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
      @supported_locales ||= Dir.glob( File.join(Rails.root, 'config', 'locales', 'client.*.yml') ).map {|x| x.split('.')[-2]}.sort
    end
  end

end
