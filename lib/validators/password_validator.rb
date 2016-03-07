require_dependency "common_passwords/common_passwords"

class PasswordValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    return unless record.password_required?
    if value.nil?
      record.errors.add(attribute, :blank)
    elsif value.length < SiteSetting.min_admin_password_length && (record.admin? || is_developer?(record.email))
      record.errors.add(attribute, :too_short, count: SiteSetting.min_admin_password_length)
    elsif value.length < SiteSetting.min_password_length
      record.errors.add(attribute, :too_short, count: SiteSetting.min_password_length)
    elsif record.username.present? && value == record.username
      record.errors.add(attribute, :same_as_username)
    elsif record.email.present? && value == record.email
      record.errors.add(attribute, :same_as_email)
    elsif SiteSetting.block_common_passwords && CommonPasswords.common_password?(value)
      record.errors.add(attribute, :common)
    end
  end

  def is_developer?(value)
    Rails.configuration.respond_to?(:developer_emails) && Rails.configuration.developer_emails.include?(value)
  end

end
