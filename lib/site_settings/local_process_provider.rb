module SiteSettings; end

class SiteSettings::LocalProcessProvider

  Setting = Struct.new(:name, :value, :data_type) unless defined? SiteSettings::LocalProcessProvider::Setting

  def initialize(defaults = {})
    @settings = {}
    @defaults = {}
    defaults.each do |name,(value,data_type)|
      @defaults[name] = Setting.new(name,value,data_type)
    end
  end

  def all
    (@defaults.merge @settings).values
  end

  def find(name)
    @settings[name] || @defaults[name]
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
