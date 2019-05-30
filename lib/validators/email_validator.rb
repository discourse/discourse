# frozen_string_literal: true

class EmailValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    unless EmailValidator.allowed?(value)
      record.errors.add(attribute, I18n.t(:'user.email.not_allowed'))
    end

    if record.errors[attribute].blank? && value && ScreenedEmail.should_block?(value)
      record.errors.add(attribute, I18n.t(:'user.email.blocked'))
    end
  end

  def self.allowed?(email)
    if (setting = SiteSetting.email_domains_whitelist).present?
      return email_in_restriction_setting?(setting, email) || is_developer?(email)
    elsif (setting = SiteSetting.email_domains_blacklist).present?
      return !(email_in_restriction_setting?(setting, email) && !is_developer?(email))
    end

    true
  end

  def self.email_in_restriction_setting?(setting, value)
    domains = setting.gsub('.', '\.')
    regexp = Regexp.new("@(.+\\.)?(#{domains})$", true)
    value =~ regexp
  end

  def self.is_developer?(value)
    Rails.configuration.respond_to?(:developer_emails) && Rails.configuration.developer_emails.include?(value)
  end

  def self.email_regex
    /\A[a-zA-Z0-9!#\$%&'*+\/=?\^_`{|}~\-]+(?:\.[a-zA-Z0-9!#\$%&'\*+\/=?\^_`{|}~\-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?$\z/
  end

end
