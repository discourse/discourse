require_dependency 'enum_site_setting'

class DigestEmailSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    val.to_i.to_s == val.to_s &&
    values.any? { |v| v[:value] == val.to_i }
  end

  def self.values
    @values ||= [
      { name: 'never',            value:  0 },
      { name: 'daily',            value:  1 },
      { name: 'every_three_days', value:  3 },
      { name: 'weekly',           value:  7 },
      { name: 'every_two_weeks',  value: 14 }
    ]
  end

  def self.translate_names?
    true
  end

end
