class Auth::Result
  attr_accessor :user, :name, :username, :email, :user,
                :email_valid, :extra_data, :awaiting_activation,
                :awaiting_approval, :authenticated, :authenticator_name,
                :requires_invite

  def session_data
    {
      email: email,
      username: username,
      email_valid: email_valid,
      name: name,
      authenticator_name: authenticator_name,
      extra_data: extra_data
    }
  end

  def to_client_hash
    if requires_invite
      { requires_invite: true }
    elsif user
      {
        authenticated: !!authenticated,
        awaiting_activation: !!awaiting_activation,
        awaiting_approval: !!awaiting_approval
      }
    else
      {
        email: email,
        name:  User.suggest_name(name || username || email),
        username: UserNameSuggester.suggest(username || name || email),
        # this feels a tad wrong
        auth_provider: authenticator_name.capitalize,
        email_valid: !!email_valid
      }
    end
  end
end
