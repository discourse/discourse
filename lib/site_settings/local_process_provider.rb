module SiteSettings; end

class SiteSettings::LocalProcessProvider

  attr_accessor :current_site

  Setting = Struct.new(:name, :value, :data_type) unless defined? SiteSettings::LocalProcessProvider::Setting

  def settings
    @settings[current_site] ||= {}
  end

  def initialize()
    @settings = {}
    self.current_site = "test"
  end

  def all
    settings.values
  end

  def find(name)
    settings[name]
  end

  def save(name, value, data_type)
    settings[name] = Setting.new(name,value, data_type)
  end

  def destroy(name)
    settings.delete(name)
  end

  def clear
    @settings[current_site] = {}
  end

end
