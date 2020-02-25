# frozen_string_literal: true

class Auth::Result
  attr_accessor :user, :name, :username, :email,
                :email_valid, :extra_data, :awaiting_activation,
                :awaiting_approval, :authenticated, :authenticator_name,
                :requires_invite, :not_allowed_from_ip_address,
                :admin_not_allowed_from_ip_address, :omit_username,
                :skip_email_validation, :destination_url, :omniauth_disallow_totp

  attr_accessor(
    :failed,
    :failed_reason,
    :failed_code
  )

  def initialize
    @failed = false
  end

  def email
    @email&.downcase
  end

  def failed?
    !!@failed
  end

  def session_data
    { email: email,
      username: username,
      email_valid: email_valid,
      omit_username: omit_username,
      name: name,
      authenticator_name: authenticator_name,
      extra_data: extra_data,
      skip_email_validation: !!skip_email_validation }
  end

  def to_client_hash
    if requires_invite
      { requires_invite: true }
    elsif user
      if user.suspended?
        {
          suspended: true,
          suspended_message: I18n.t(user.suspend_reason ? "login.suspended_with_reason" : "login.suspended",
                                     date: I18n.l(user.suspended_till, format: :date_only), reason: user.suspend_reason)
        }
      else
        result =
          if omniauth_disallow_totp
            {
              omniauth_disallow_totp: !!omniauth_disallow_totp,
              email: email
            }
          else
            {
              authenticated: !!authenticated,
              awaiting_activation: !!awaiting_activation,
              awaiting_approval: !!awaiting_approval,
              not_allowed_from_ip_address: !!not_allowed_from_ip_address,
              admin_not_allowed_from_ip_address: !!admin_not_allowed_from_ip_address
            }
          end

        result[:destination_url] = destination_url if authenticated && destination_url.present?
        result
      end
    else
      result = { email: email,
                 username: UserNameSuggester.suggest(username || name || email),
                 auth_provider: authenticator_name,
                 email_valid: !!email_valid,
                 omit_username: !!omit_username }

      result[:destination_url] = destination_url if destination_url.present?

      if SiteSetting.enable_names?
        result[:name] = name.presence || User.suggest_name(username || email)
      end

      result
    end
  end
end
