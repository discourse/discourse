class Auth::Result
  attr_accessor :user, :name, :username, :email, :user,
                :email_valid, :extra_data, :awaiting_activation,
                :awaiting_approval, :authenticated, :authenticator_name,
                :requires_invite, :not_allowed_from_ip_address,
                :admin_not_allowed_from_ip_address, :omit_username

  attr_accessor :failed,
                :failed_reason

  def initialize
    @failed = false
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
      extra_data: extra_data }
  end

  def to_client_hash
    if requires_invite
      { requires_invite: true }
    elsif user
      if user.suspended?
        {
          suspended: true,
          suspended_message: I18n.t( user.suspend_reason ? "login.suspended_with_reason" : "login.suspended",
                                     {date: I18n.l(user.suspended_till, format: :date_only), reason: user.suspend_reason} )
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
    else
      {
        email: email,
        name:  User.suggest_name(name || username || email),
        username: UserNameSuggester.suggest(username || name || email),
        # this feels a tad wrong
        auth_provider: authenticator_name.capitalize,
        email_valid: !!email_valid,
        omit_username: !!omit_username
      }
    end
  end
end
