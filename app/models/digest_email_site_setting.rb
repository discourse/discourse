require_dependency 'enum_site_setting'

class DigestEmailSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    val.blank? or values.any? { |v| v[:value] == val.to_s }
  end

  def self.values
    @values ||= [
      {name: 'never',           value: ''   },
      {name: 'daily',           value: '1'  },
      {name: 'weekly',          value: '7'  },
      {name: 'every_two_weeks', value: '14' }
    ]
  end

  def self.translate_names?
    true
  end

end
