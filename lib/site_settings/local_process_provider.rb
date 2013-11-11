module SiteSettings; end

class SiteSettings::LocalProcessProvider

  Setting = Struct.new(:name, :value, :data_type) unless defined? SiteSettings::LocalProcessProvider::Setting

  def initialize
    @settings = {}
  end

  def all
    @settings.values
  end

  def find(name)
    @settings[name]
  end

  def save(name, value, data_type)
    @settings[name] = Setting.new(name,value, data_type)
  end

  def destroy(name)
    @settings.delete(name)
  end

  def current_site
    "test"
  end

end
