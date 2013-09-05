require_dependency 'enum_site_setting'

class MinTrustToCreateTopicSetting < EnumSiteSetting

  def self.valid_value?(val)
    valid_values.any? { |v| v.to_s == val.to_s }
  end

  def self.values
    @values ||= valid_values.map {|x| {name: x.to_s, value: x} }
  end

  private

  def self.valid_values
    TrustLevel.levels.values.sort
  end
end
