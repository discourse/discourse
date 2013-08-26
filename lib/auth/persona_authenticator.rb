class Auth::PersonaAuthenticator < Auth::Authenticator

  def name
    "persona"
  end

  # TODO twitter provides all sorts of extra info, like website/bio etc.
  #  it may be worth considering pulling some of it in.
  def after_authenticate(auth_token)
    result = Auth::Result.new

    result.email = email = auth_token[:info][:email]
    result.email_valid = true

    result.user = User.find_by_email(email)
    result
  end

  def register_middleware(omniauth)
    omniauth.provider :browser_id,
           :name => "persona"
  end
end


