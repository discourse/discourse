# frozen_string_literal: true

class Auth::GoogleOAuth2Authenticator < Auth::ManagedAuthenticator
  def name
    "google_oauth2"
  end

  def enabled?
    SiteSetting.enable_google_oauth2_logins
  end

  def primary_email_verified?(auth_token)
    # note, emails that come back from google via omniauth are always valid
    # this protects against future regressions
    auth_token[:extra][:raw_info][:email_verified]
  end

  def register_middleware(omniauth)
    strategy_class = Auth::OmniAuthStrategies::DiscourseGoogleOauth2
    options = {
      setup: lambda { |env|
        strategy = env["omniauth.strategy"]
        strategy.options[:client_id] = SiteSetting.google_oauth2_client_id
        strategy.options[:client_secret] = SiteSetting.google_oauth2_client_secret

        if (google_oauth2_hd = SiteSetting.google_oauth2_hd).present?
          strategy.options[:hd] = google_oauth2_hd
        end

        if (google_oauth2_prompt = SiteSetting.google_oauth2_prompt).present?
          strategy.options[:prompt] = google_oauth2_prompt.gsub("|", " ")
        end

        # All the data we need for the `info` and `credentials` auth hash
        # are obtained via the user info API, not the JWT. Using and verifying
        # the JWT can fail due to clock skew, so let's skip it completely.
        # https://github.com/zquestz/omniauth-google-oauth2/pull/392
        strategy.options[:skip_jwt] = true
        strategy.options[:request_groups] = provides_groups?

        if provides_groups?
          strategy.options[:scope] = "#{strategy_class::DEFAULT_SCOPE},#{strategy_class::GROUPS_SCOPE}"
        end
      }
    }
    omniauth.provider strategy_class, options
  end

  def after_authenticate(auth_token, existing_account: nil)
    result = super
    if provides_groups? && (groups = auth_token[:extra][:raw_groups])
      result.associated_groups = groups.map { |group| group.slice(:id, :name) }
    end
    result
  end

  def provides_groups?
    SiteSetting.google_oauth2_hd.present? && SiteSetting.google_oauth2_hd_groups
  end
end
