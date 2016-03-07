require_dependency 'enum_site_setting'

class DigestEmailSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    val.to_i.to_s == val.to_s &&
    values.any? { |v| v[:value] == val.to_i }
  end

  def self.values
    @values ||= [
      { name: 'never',            value:  0 },
      { name: 'every_30_minutes', value:  30 },
      { name: 'every_hour',       value:  60 },
      { name: 'daily',            value:  1440 },
      { name: 'every_three_days', value:  4320 },
      { name: 'weekly',           value:  10080 },
      { name: 'every_two_weeks',  value:  20160 }
    ]
  end

  def self.translate_names?
    true
  end

end
