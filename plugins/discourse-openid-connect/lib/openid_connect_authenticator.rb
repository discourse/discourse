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

  def always_update_user_email?
    SiteSetting.openid_connect_overrides_email
  end

  def match_by_email
    SiteSetting.openid_connect_match_by_email
  end

  def match_by_username
    SiteSetting.openid_connect_match_by_username
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

  def request_timeout_seconds
    GlobalSetting.openid_connect_request_timeout_seconds
  end

  def set_oidc_mapped_groups(user, auth)
    return unless SiteSetting.openid_connect_groups_enabled

    if !(auth && auth.dig(:extra, :raw_info, :groups))
      oidc_log("OpenID Connect groups enabled but no group information passed by provider. Not changing groups.")
      return
    end

    user_oidc_groups = auth[:extra][:raw_info][:groups]
    group_map = {}
    check_groups = {}

    SiteSetting.openid_connect_groups_maps.split("|").each do |map|
      keyval = map.split(":", 2)
      group_map[keyval[0]] = keyval[1]
      keyval[1].split(",").each { |discourse_group|
        check_groups[discourse_group] = 0
      }
    end

    if !(user_oidc_groups == nil || group_map.empty?)
      user_oidc_groups.each { |user_oidc_group|
        if group_map.has_key?(user_oidc_group) #??? || !SiteSetting.openid_connect_groups_remove_unmapped_groups
          result = nil

          discourse_groups = group_map[user_oidc_group] || ""
          discourse_groups.split(",").each { |discourse_group|
            next unless discourse_group

            actual_group = Group.find_by(name: discourse_group)
            if (!actual_group)
              oidc_log("OIDC group '#{user_oidc_group}' maps to Group '#{discourse_group}' but this does not seem to exist")
              next
            end
            if actual_group.automatic # skip if it's an auto_group
              oidc_log("Group '#{discourse_group}' is an automatic, cannot change membership")
              next
            end
            check_groups[discourse_group] = 1
            result = actual_group.add(user)
            oidc_log("OIDC group '#{user_oidc_group}' mapped to Group '#{discourse_group}'. User '#{user.username}' has been added") if result
          }
        end
      }
    end

    if SiteSetting.openid_connect_groups_remove_unmapped_groups
      check_groups.keys.each { |discourse_group|
        actual_group = Group.find_by(name: discourse_group)
        if check_groups[discourse_group] > 0
          next
        end
        if !actual_group
          oidc_log("DEBUG: Group '#{discourse_group}' can't be found, cannot remove user '#{user.username}'")
          next
        end
        if actual_group.automatic # skip if it's an auto_group
          oidc_log("DEBUG: Group '#{discourse_group}' is automatic, cannot change membership")
          next
        end
        result = actual_group.remove(user)
        oidc_log("DEBUG: User '#{user.username}' removed from Group '#{discourse_group}'") if result
      }
    end
  end

  def after_authenticate(auth, existing_account: nil)
    result = super(auth, existing_account: existing_account)
    if result.user != nil
      set_oidc_mapped_groups(result.user, auth)
    end
    result
  end

  def after_create_account(user, auth)
    super(user, auth)
    set_groups(user, auth)
  end

end
