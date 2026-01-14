# frozen_string_literal: true

require "has_errors"

class Auth::GithubAuthenticator < Auth::ManagedAuthenticator
  def name
    "github"
  end

  def display_name
    "GitHub"
  end

  def provider_url
    "https://github.com"
  end

  def enabled?
    SiteSetting.enable_github_logins
  end

  def after_authenticate(auth_token, existing_account: nil)
    result = super
    return result if result.user
    # If email domain restrictions are configured,
    # pick a secondary email which is allowed
    all_github_emails(auth_token).each do |candidate|
      next if !EmailValidator.allowed?(candidate[:email])
      result.email = candidate[:email]
      result.email_valid = !!candidate[:verified]
      break
    end

    result
  end

  def find_user_by_email(auth_token)
    # Use verified secondary emails to find a match
    all_github_emails(auth_token).each do |candidate|
      next if !candidate[:verified]
      if user = User.find_by_email(candidate[:email])
        return user
      end
    end
    nil
  end

  def all_github_emails(auth_token)
    emails = Array.new(auth_token[:extra][:all_emails])
    primary_email = emails.find { |email| email[:primary] }
    if primary_email
      emails.delete(primary_email)
      emails.unshift(primary_email)
    end
    emails
  end

  def register_middleware(omniauth)
    omniauth.provider :github,
                      setup:
                        lambda { |env|
                          strategy = env["omniauth.strategy"]
                          strategy.options[:client_id] = SiteSetting.github_client_id
                          strategy.options[:client_secret] = SiteSetting.github_client_secret
                        },
                      scope: "user:email"
  end

  # the omniauth-github gem only picks up the primary email if it's verified:
  # https://github.com/omniauth/omniauth-github/blob/0ac46b59ccdabd4cbe5be4a665df269355081915/lib/omniauth/strategies/github.rb#L58-L61
  def primary_email_verified?(auth_token)
    true
  end
end
