# frozen_string_literal: true

class Auth::LinkedInOidcAuthenticator < Auth::ManagedAuthenticator
  class LinkedInOidc < OmniAuth::Strategies::OAuth2
    option :name, "linkedin_oidc"

    option :client_options,
           {
             site: "https://api.linkedin.com",
             authorize_url: "https://www.linkedin.com/oauth/v2/authorization?response_type=code",
             token_url: "https://www.linkedin.com/oauth/v2/accessToken",
           }

    option :scope, "openid profile email"
    option :fields, %w[id full-name first-name last-name picture-url email-address]
    option :redirect_url

    uid { raw_info["sub"] }

    info do
      {
        email: raw_info["email"],
        first_name: raw_info["given_name"],
        last_name: raw_info["family_name"],
        picture_url: raw_info["picture"],
      }
    end

    extra { { "raw_info" => raw_info } }

    def callback_url
      full_host + script_name + callback_path
    end

    alias oauth2_access_token access_token

    def access_token
      ::OAuth2::AccessToken.new(
        client,
        oauth2_access_token.token,
        {
          expires_in: oauth2_access_token.expires_in,
          expires_at: oauth2_access_token.expires_at,
          refresh_token: oauth2_access_token.refresh_token,
        },
      )
    end

    def raw_info
      @raw_info ||= access_token.get(profile_endpoint).parsed
    end

    private

    def fields_mapping
      # https://learn.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/sign-in-with-linkedin-v2?context=linkedin%2Fconsumer%2Fcontext#api-request-to-retreive-member-details
      {
        "id" => "sub",
        "full-name" => "name",
        "first-name" => "given_name",
        "last-name" => "family_name",
        "picture-url" => "picture",
      }
    end

    def fields
      options
        .fields
        .each
        .with_object([]) do |field, result|
          result << fields_mapping[field] if fields_mapping.has_key? field
        end
    end

    def profile_endpoint
      "/v2/userinfo"
    end
  end

  def name
    "linkedin_oidc"
  end

  def enabled?
    SiteSetting.enable_linkedin_oidc_logins
  end

  def register_middleware(omniauth)
    omniauth.provider LinkedInOidc,
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
