# frozen_string_literal: true

class User::Action::CreateFromVerifiedEmail < Service::ActionBase
  option :email
  option :ip_address, optional: true
  option :user_fields, optional: true

  def call
    username = UserNameSuggester.suggest(email)

    user = User.where(staged: true).with_email(email).first
    user&.unstage!
    user ||= User.new

    user.attributes = {
      email: email,
      username: username,
      name: username,
      active: false,
      locale: I18n.locale,
      ip_address: ip_address,
      registration_ip_address: ip_address,
    }

    assign_user_fields(user)

    if SiteSetting.must_approve_users? && EmailValidator.can_auto_approve_user?(email)
      ReviewableUser.set_approved_fields!(user, Discourse.system_user)
    end

    user.save!
    user
  end

  private

  def assign_user_fields(user)
    return if user_fields.blank?

    fields = user.custom_fields
    UserField
      .where(show_on_signup: true)
      .pluck(:id)
      .each do |field_id|
        value = user_fields[field_id.to_s]
        value = nil if value == "false"
        fields["#{User::USER_FIELD_PREFIX}#{field_id}"] = value[
          0...UserField.max_length
        ] if value.present?
      end
    user.custom_fields = fields
  end
end
