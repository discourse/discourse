# frozen_string_literal: true

module SiteSettings
end

class SiteSettings::LocalProcessProvider
  class Setting
    attr_accessor :name, :data_type, :value

    def value_changed?
      false
    end

    def saved_change_to_value?
      true
    end

    def initialize(name, data_type)
      self.name = name
      self.data_type = data_type
    end
  end

  def settings
    @settings[current_site] ||= {}
  end

  def initialize
    @settings = {}
  end

  def all
    settings.values
  end

  def find(name)
    settings[name]
  end

  def save(name, value, data_type)
    # NOTE: convert to string to simulate the conversion that is happening
    # when using DbProvider
    setting = settings[name]
    if setting.blank?
      setting = Setting.new(name, data_type)
      settings[name] = setting
    end
    setting.value = value.to_s

    setting
  end

  def destroy(name)
    settings.delete(name)
  end

  def clear
    @settings[current_site] = {}
  end

  def current_site
    RailsMultisite::ConnectionManagement.current_db
  end
end
