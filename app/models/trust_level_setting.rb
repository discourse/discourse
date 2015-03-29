require_dependency 'enum_site_setting'

class TrustLevelSetting < EnumSiteSetting

  def self.valid_value?(val)
    valid_values.any? { |v| v.to_s == val.to_s }
  end

  def self.values
    @values ||= valid_values.map {|x| {name: x.to_s, value: x} }
  end

  def self.valid_values
    TrustLevel.valid_range.to_a
  end

  private_class_method :valid_values
end
