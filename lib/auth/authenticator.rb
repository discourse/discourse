# this class is used by the user and omniauth controllers, it controls how
#  an authentication system interacts with our database and middleware

class Auth::Authenticator
  def after_authenticate(auth_options)
    raise NotImplementedError
  end

  # can be used to hook in after the authentication process
  #  to ensure records exist for the provider in the db
  #  this MUST be implemented for authenticators that do not
  #  trust email
  def after_create_account(user, auth)
    # not required
  end

  # hook used for registering omniauth middleware,
  #  without this we can not authenticate
  def register_middleware(omniauth)
    raise NotImplementedError
  end
end
