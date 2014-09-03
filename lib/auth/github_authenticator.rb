class Auth::GithubAuthenticator < Auth::Authenticator

  def name
    "github"
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    data = auth_token[:info]

    result.username = screen_name = data["nickname"]
    result.email = email = data["email"]

    github_user_id = auth_token["uid"]

    result.extra_data = {
      github_user_id: github_user_id,
      github_screen_name: screen_name,
    }

    user_info = GithubUserInfo.find_by(github_user_id: github_user_id)
    result.email_valid = !!data["email_verified"]

    if user_info
      user = user_info.user
    elsif result.email_valid && (user = User.find_by_email(email))
      user_info = GithubUserInfo.create(
          user_id: user.id,
          screen_name: screen_name,
          github_user_id: github_user_id
      )
    end

    result.user = user

    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    GithubUserInfo.create(
      user_id: user.id,
      screen_name: data[:github_screen_name],
      github_user_id: data[:github_user_id]
    )
  end


  def register_middleware(omniauth)
    omniauth.provider :github,
           :setup => lambda { |env|
              strategy = env["omniauth.strategy"]
              strategy.options[:client_id] = SiteSetting.github_client_id
              strategy.options[:client_secret] = SiteSetting.github_client_secret
           },
           :scope => "user:email"
  end
end
