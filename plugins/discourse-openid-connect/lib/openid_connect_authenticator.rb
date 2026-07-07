# frozen_string_literal: true
require "base64"
require "openssl"

class OpenIDConnectAuthenticator < Auth::ManagedAuthenticator
  def name
    "oidc"
  end

  def can_revoke?
    SiteSetting.openid_connect_allow_association_change
  end

  def can_connect_existing_user?
    SiteSetting.openid_connect_allow_association_change
  end

  def enabled?
    SiteSetting.openid_connect_enabled
  end

  def primary_email_verified?(auth)
    supplied_verified_boolean = auth["extra"]["raw_info"]["email_verified"]
    # If the payload includes the email_verified boolean, use it. Otherwise assume true
    if supplied_verified_boolean.nil?
      true
    else
      # Many providers violate the spec, and send this as a string rather than a boolean
      supplied_verified_boolean == true ||
        (supplied_verified_boolean.is_a?(String) && supplied_verified_boolean.downcase == "true")
    end
  end

  def provides_groups?
    SiteSetting.openid_connect_groups_claim.present?
  end

  def after_authenticate(auth_token, existing_account: nil)
    result = super

    if provides_groups?
      claim = SiteSetting.openid_connect_groups_claim
      result.associated_groups = []
      groups =
        auth_token.extra&.dig(:raw_info, claim) || auth_token.extra&.dig(:id_token_info, claim)

      if groups.is_a?(Array)
        result.associated_groups = groups.map { |group_name| { id: group_name, name: group_name } }
      elsif groups.present?
        oidc_log("groups claim '#{claim}' is not an array: #{groups.class}", error: true)
      else
        oidc_log("groups claim '#{claim}' not found in auth token")
      end
    end

    result.user_field_values = user_field_values_from(auth_token)

    result
  end

  def user_field_values_from(auth_token)
    mappings = JSON.parse(SiteSetting.openid_connect_user_field_mappings.presence || "[]")
    return {} if mappings.blank?

    raw_info = auth_token.extra&.[](:raw_info)
    id_token_info = auth_token.extra&.[](:id_token_info)

    mappings.each_with_object({}) do |mapping, hash|
      claim = mapping["claim"].to_s
      field_id = mapping["user_field_id"]
      next if claim.blank? || field_id.blank?

      source =
        if raw_info&.key?(claim)
          raw_info
        elsif id_token_info&.key?(claim)
          id_token_info
        end
      next if source.nil?

      value = source[claim]
      hash[field_id.to_s] = value.is_a?(Array) ? value.join(",") : value.to_s
    end
  rescue JSON::ParserError
    {}
  end

  def always_update_user_email?
    SiteSetting.openid_connect_overrides_email
  end

  def match_by_email
    SiteSetting.openid_connect_match_by_email
  end

  def discovery_document
    document_url = SiteSetting.openid_connect_discovery_document.presence
    if !document_url
      oidc_log("No discovery document URL specified", error: true)
      return
    end

    from_cache = true
    result =
      Discourse
        .cache
        .fetch("openid-connect-discovery-#{document_url}", expires_in: 10.minutes) do
          from_cache = false
          oidc_log("Fetching discovery document from #{document_url}")
          connection =
            Faraday.new(request: { timeout: request_timeout_seconds }) do |c|
              c.use Faraday::Response::RaiseError
              c.adapter FinalDestination::FaradayAdapter
            end
          JSON.parse(connection.get(document_url).body)
        rescue Faraday::Error, JSON::ParserError => e
          oidc_log("Fetching discovery document raised error #{e.class} #{e.message}", error: true)
          nil
        end

    oidc_log("Discovery document loaded from cache") if from_cache
    oidc_log("Discovery document is\n\n#{result.to_yaml}")

    result
  end

  def oidc_log(message, error: false)
    if error
      Rails.logger.error("OIDC Log: #{message}")
    elsif SiteSetting.openid_connect_verbose_logging
      Rails.logger.warn("OIDC Log: #{message}")
    end
  end

  def register_middleware(omniauth)
    omniauth.provider :openid_connect,
                      name: :oidc,
                      error_handler:
                        lambda { |error, message|
                          handlers = SiteSetting.openid_connect_error_redirects.split("\n")
                          handlers.each do |row|
                            parts = row.split("|")
                            return parts[1] if message.include? parts[0]
                          end
                          nil
                        },
                      verbose_logger: lambda { |message| oidc_log(message) },
                      setup:
                        lambda { |env|
                          opts = env["omniauth.strategy"].options

                          token_params = {}
                          token_params[
                            :scope
                          ] = SiteSetting.openid_connect_token_scope if SiteSetting.openid_connect_token_scope.present?

                          opts.deep_merge!(
                            client_id: SiteSetting.openid_connect_client_id,
                            client_secret: SiteSetting.openid_connect_client_secret,
                            discovery_document: discovery_document,
                            scope: SiteSetting.openid_connect_authorize_scope,
                            token_params: token_params,
                            passthrough_authorize_options:
                              SiteSetting.openid_connect_authorize_parameters.split("|"),
                            claims: SiteSetting.openid_connect_claims,
                            pkce: SiteSetting.openid_connect_use_pkce,
                            pkce_options: {
                              code_verifier: -> { generate_code_verifier },
                              code_challenge: ->(code_verifier) do
                                generate_code_challenge(code_verifier)
                              end,
                              code_challenge_method: "S256",
                            },
                          )

                          opts[:client_options][:connection_opts] = {
                            request: {
                              timeout: request_timeout_seconds,
                            },
                          }

                          ssl_opts = mtls_ssl_options
                          if ssl_opts.present?
                            opts[:client_options][:auth_scheme] = :tls_client_auth
                            opts[:client_options][:connection_opts][:ssl] = ssl_opts
                          end

                          opts[:client_options][:connection_build] = lambda do |builder|
                            if SiteSetting.openid_connect_verbose_logging
                              builder.response :logger,
                                               Rails.logger,
                                               { bodies: true, formatter: OIDCFaradayFormatter }
                            end

                            builder.request :url_encoded # form-encode POST params
                            builder.adapter FinalDestination::FaradayAdapter # make requests with FinalDestination::HTTP
                          end
                        }
  end

  def generate_code_verifier
    Base64.urlsafe_encode64(OpenSSL::Random.random_bytes(32)).tr("=", "")
  end

  def generate_code_challenge(code_verifier)
    Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier)).tr("+/", "-_").tr("=", "")
  end

  def mtls_ssl_options
    cert_pem = SiteSetting.openid_connect_mtls_client_cert
    key_pem = SiteSetting.openid_connect_mtls_client_key
    return {} if cert_pem.blank? || key_pem.blank?

    {
      client_cert: OpenSSL::X509::Certificate.new(cert_pem),
      client_key: OpenSSL::PKey.read(key_pem),
    }
  rescue OpenSSL::OpenSSLError => e
    oidc_log("Failed to parse mTLS certificate or key: #{e.message}", error: true)
    {}
  end

  def request_timeout_seconds
    GlobalSetting.openid_connect_request_timeout_seconds
  end
end
