require_dependency 'enum_site_setting'

class PreviousRepliesSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    val.to_i.to_s == val.to_s &&
    values.any? { |v| v[:value] == val.to_i }
  end

  def self.values
    @values ||= [
      { name: 'user.email_previous_replies.always',  value:  0 },
      { name: 'user.email_previous_replies.unless_emailed',   value:  1 },
      { name: 'user.email_previous_replies.never', value:  2 },
    ]
  end

  def self.translate_names?
    true
  end

end
