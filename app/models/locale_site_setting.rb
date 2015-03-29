require_dependency 'enum_site_setting'

class LocaleSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    supported_locales.include?(val)
  end

  def self.values
    supported_locales.map do |l|
      {name: l, value: l}
    end
  end

  @lock = Mutex.new

  def self.supported_locales
    @lock.synchronize do
      @supported_locales ||= Dir.glob( File.join(Rails.root, 'config', 'locales', 'client.*.yml') ).map {|x| x.split('.')[-2]}.sort
    end
  end

end
