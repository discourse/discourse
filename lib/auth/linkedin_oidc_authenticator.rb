# frozen_string_literal: true

class Auth::LinkedInOidcAuthenticator < Auth::ManagedAuthenticator
  def name
    "linkedin"
  end

  def enabled?
    SiteSetting.enable_linkedin_oidc_logins
  end

  def register_middleware(omniauth)
    omniauth.provider :linkedin,
                      setup:
                        lambda { |env|
                          strategy = env["omniauth.strategy"]
                          strategy.options[:client_id] = SiteSetting.linkedin_oidc_client_id
                          strategy.options[:client_secret] = SiteSetting.linkedin_oidc_client_secret
                        }
  end

  # LinkedIn doesn't let users login to websites unless they verify their e-mail
  # address, so whatever e-mail we get from LinkedIn must be verified.
  def primary_email_verified?(_auth_token)
    true
  end
end
