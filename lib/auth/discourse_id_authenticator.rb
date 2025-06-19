# frozen_string_literal: true

class Auth::DiscourseIdAuthenticator < Auth::ManagedAuthenticator
  class DiscourseIdStrategy < ::OmniAuth::Strategies::OAuth2
    option :name, "discourse_id"

    option :client_options, auth_scheme: :basic_auth

    def authorize_params
      super.tap { _1[:intent] = "signup" if request.params["signup"] == "true" }
    end

    def callback_url
      Discourse.base_url_no_prefix + callback_path
    end

    uid { access_token.params["info"]["uuid"] }

    info do
      {
        nickname: access_token.params["info"]["username"],
        email: access_token.params["info"]["email"],
        image: access_token.params["info"]["image"],
      }
    end
  end

  def name
    "discourse_id"
  end

  def display_name
    "Discourse ID"
  end

  def provider_url
    site
  end

  def enabled?
    SiteSetting.enable_discourse_id && SiteSetting.discourse_id_client_id.present? &&
      SiteSetting.discourse_id_client_secret.present?
  end

  def site
    SiteSetting.discourse_id_provider_url.presence || "https://id.discourse.com"
  end

  def register_middleware(omniauth)
    omniauth.provider DiscourseIdStrategy,
                      scope: "read",
                      setup: ->(env) do
                        env["omniauth.strategy"].options.merge!(
                          client_id: SiteSetting.discourse_id_client_id,
                          client_secret: SiteSetting.discourse_id_client_secret,
                          client_options: {
                            site:,
                          },
                        )
                      end
  end

  def primary_email_verified?(auth_token)
    true # email will be verified at source
  end
end
