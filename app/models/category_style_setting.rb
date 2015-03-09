# TODO all enums should probably move out of models
# TODO we should be able to do this kind of stuff without a backing class
require_dependency 'enum_site_setting'

class CategoryStyleSetting < EnumSiteSetting

  VALUES = ["bar", "box", "bullet"]

  def self.valid_value?(val)
    VALUES.include?(val)
  end

  def self.values
    VALUES.map do |l|
      {name: l, value: l}
    end
  end

end
