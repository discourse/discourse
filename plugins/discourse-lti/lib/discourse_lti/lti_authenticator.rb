# frozen_string_literal: true

class ::DiscourseLti::LtiAuthenticator < Auth::ManagedAuthenticator
  def name
    "lti"
  end

  def can_revoke?
    true
  end

  def can_connect_existing_user?
    # Connection is possible, but must be initiated by the IdP.
    # Discourse's "connect" button is hidden using javascript.
    true
  end

  def enabled?
    SiteSetting.lti_enabled
  end

  def primary_email_verified?(auth)
    SiteSetting.lti_email_verified?
  end

  def register_middleware(omniauth)
    omniauth.provider ::DiscourseLti::LtiOmniauthStrategy,
                      name: :lti,
                      setup:
                        lambda { |env|
                          opts = env["omniauth.strategy"].options
                          opts.deep_merge!(
                            client_ids: SiteSetting.lti_client_ids.split("|"),
                            authorize_url: SiteSetting.lti_authorization_endpoint,
                            platform_issuer_id: SiteSetting.lti_platform_issuer_id,
                            platform_public_key: SiteSetting.lti_platform_public_key,
                          )
                        }
  end
end
