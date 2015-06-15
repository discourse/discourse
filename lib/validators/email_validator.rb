class EmailValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    if (setting = SiteSetting.email_domains_whitelist).present?
      unless email_in_restriction_setting?(setting, value) || is_developer?(value)
        record.errors.add(attribute, I18n.t(:'user.email.not_allowed'))
      end
    elsif (setting = SiteSetting.email_domains_blacklist).present?
      if email_in_restriction_setting?(setting, value) && !is_developer?(value)
        record.errors.add(attribute, I18n.t(:'user.email.not_allowed'))
      end
    end
    if record.errors[attribute].blank? && value && ScreenedEmail.should_block?(value)
      record.errors.add(attribute, I18n.t(:'user.email.blocked'))
    end
  end

  def email_in_restriction_setting?(setting, value)
    domains = setting.gsub('.', '\.')
    regexp = Regexp.new("@(.+\\.)?(#{domains})", true)
    value =~ regexp
  end

  def is_developer?(value)
    Rails.configuration.respond_to?(:developer_emails) && Rails.configuration.developer_emails.include?(value)
  end

  def self.email_regex
    /^[a-zA-Z0-9!#\$%&'*+\/=?\^_`{|}~\-]+(?:\.[a-zA-Z0-9!#\$%&'\*+\/=?\^_`{|}~\-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?$/
  end

end
