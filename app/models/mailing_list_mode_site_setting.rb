require_dependency 'enum_site_setting'

class MailingListModeSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    val.to_i.to_s == val.to_s &&
    values.any? { |v| v[:value] == val.to_i }
  end

  def self.values
    @values ||= [
      { name: 'user.mailing_list_mode.daily',      value:  0 },
      { name: 'user.mailing_list_mode.individual', value:  1 }
    ]
  end

  def self.translate_names?
    true
  end
end
