class Auth::CasAuthenticator < Auth::Authenticator

  def name
    'cas'
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    email = auth_token[:info][:email] if auth_token[:info]
    email ||= if SiteSetting.cas_domainname.present?
      "#{auth_token[:extra][:user]}@#{SiteSetting.cas_domainname}"
    else
      auth_token[:extra][:user]
    end

    result.email = email
    result.email_valid = true

    result.username = username = auth_token[:extra][:user]

    result.name = name = if auth_token[:info] && auth_token[:info][:name]
      auth_token[:info][:name]
    else
      auth_token["uid"]
    end

    cas_user_id = auth_token["uid"]

    result.extra_data = {
      cas_user_id: cas_user_id
    }

    user_info = CasUserInfo.where(:cas_user_id => cas_user_id ).first

    result.user = user_info.try(:user)
    result.user ||= User.where(email: email).first
    # TODO, create CAS record ?

    result
  end

  def register_middleware(omniauth)
    omniauth.provider :cas,
           :host => SiteSetting.cas_hostname
  end
end
