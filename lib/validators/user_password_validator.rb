# frozen_string_literal: true

class UserPasswordValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    # TODO: fix the following translation key error, it's under the user model atmError encountered while proccessing /u.json  I18n::MissingTranslationData: Translation missing. Options considered were:
    # - en.activerecord.errors.models.user_password.attributes.password.same_as_current
    # - en.activerecord.errors.models.user_password.same_as_current
    # - en.activerecord.errors.messages.same_as_current
    # - en.errors.attributes.password.same_as_current
    return unless record.password_validation_required?
    user = record.user

    if value.nil?
      record.errors.add(attribute, :blank)
    elsif value.length < SiteSetting.min_admin_password_length &&
          (user.admin? || is_developer?(user.email))
      record.errors.add(attribute, :too_short, count: SiteSetting.min_admin_password_length)
    elsif value.length < SiteSetting.min_password_length
      record.errors.add(attribute, :too_short, count: SiteSetting.min_password_length)
    elsif user.username.present? && value == user.username
      record.errors.add(attribute, :same_as_username)
    elsif user.name.present? && value == user.name
      record.errors.add(attribute, :same_as_name)
    elsif user.email.present? && value == user.email
      record.errors.add(attribute, :same_as_email)
    elsif user.confirm_password?(value)
      record.errors.add(attribute, :same_as_current)
    elsif user.password_expired?(value)
      record.errors.add(attribute, :same_as_previous)
    elsif SiteSetting.block_common_passwords && CommonPasswords.common_password?(value)
      record.errors.add(attribute, :common)
    elsif value.chars.uniq.length < SiteSetting.password_unique_characters
      record.errors.add(attribute, :unique_characters)
    end
  end

  def is_developer?(value)
    Rails.configuration.respond_to?(:developer_emails) &&
      Rails.configuration.developer_emails.include?(value)
  end
end
