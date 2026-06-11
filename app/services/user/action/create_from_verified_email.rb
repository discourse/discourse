# frozen_string_literal: true

class User::Action::CreateFromVerifiedEmail < Service::ActionBase
  option :email
  option :ip_address, optional: true

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

    if SiteSetting.must_approve_users? && EmailValidator.can_auto_approve_user?(email)
      ReviewableUser.set_approved_fields!(user, Discourse.system_user)
    end

    user.save!
    user
  end
end
