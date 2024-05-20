# frozen_string_literal: true

module OmniauthHelpers
  FIRST_NAME = "John"
  LAST_NAME = "Doe"
  FULL_NAME = "John Doe"
  USERNAME = "john"
  EMAIL = "johndoe@example.com"

  def mock_facebook_auth(email: EMAIL, name: FULL_NAME)
    OmniAuth.config.mock_auth[:facebook] = OmniAuth::AuthHash.new(
      provider: "facebook",
      uid: "12345",
      info: OmniAuth::AuthHash::InfoHash.new(email: email, name: name),
    )

    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:facebook]
  end

  def mock_google_auth(email: EMAIL, name: FULL_NAME, verified: true)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "12345",
      info: OmniAuth::AuthHash::InfoHash.new(email: email, name: name),
      extra: {
        raw_info: {
          email_verified: verified,
        },
      },
    )

    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
  end

  def mock_github_auth(email: EMAIL, nickname: USERNAME, name: FULL_NAME, verified: true)
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "12345",
      info: OmniAuth::AuthHash::InfoHash.new(email: email, nickname: nickname, name: name),
      extra: {
        all_emails: [{ email: email, primary: true, verified: verified, visibility: "private" }],
      },
    )

    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:github]
  end

  def mock_twitter_auth(nickname: USERNAME, name: FULL_NAME, verified: true)
    OmniAuth.config.mock_auth[:twitter] = OmniAuth::AuthHash.new(
      provider: "twitter",
      uid: "12345",
      info: OmniAuth::AuthHash::InfoHash.new(nickname: nickname, name: name),
    )

    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:twitter]
  end

  def mock_discord_auth(email: EMAIL, username: USERNAME, name: FULL_NAME)
    OmniAuth.config.mock_auth[:discord] = OmniAuth::AuthHash.new(
      provider: "discord",
      uid: "12345",
      info: OmniAuth::AuthHash::InfoHash.new(email: email, name: name),
    )

    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:discord]
  end

  def mock_linkedin_auth(email: EMAIL, first_name: FIRST_NAME, last_name: LAST_NAME)
    OmniAuth.config.mock_auth[:linkedin_oidc] = OmniAuth::AuthHash.new(
      provider: "linkedin_oidc",
      uid: "12345",
      info:
        OmniAuth::AuthHash::InfoHash.new(
          email: email,
          first_name: first_name,
          last_name: last_name,
        ),
    )

    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:linkedin_oidc]
  end

  def reset_omniauth_config(provider)
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[provider] = nil
    Rails.application.env_config["omniauth.auth"] = nil
  end
end
