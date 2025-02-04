# frozen_string_literal: true

class Auth::GoogleOAuth2Authenticator < Auth::ManagedAuthenticator
  GROUPS_SCOPE = "https://www.googleapis.com/auth/admin.directory.group.readonly"
  GROUPS_DOMAIN = "admin.googleapis.com"
  GROUPS_PATH = "/admin/directory/v1/groups"
  OAUTH2_BASE_URL = "https://oauth2.googleapis.com"

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
    options = {
      setup:
        lambda do |env|
          opts = env["omniauth.strategy"].options
          opts[:client_id] = SiteSetting.google_oauth2_client_id
          opts[:client_secret] = SiteSetting.google_oauth2_client_secret

          if (google_oauth2_hd = SiteSetting.google_oauth2_hd).present?
            opts[:hd] = google_oauth2_hd
          end

          if (google_oauth2_prompt = SiteSetting.google_oauth2_prompt).present?
            opts[:prompt] = google_oauth2_prompt.gsub("|", " ")
          end
          opts[:client_options][:connection_build] = lambda do |builder|
            if SiteSetting.google_oauth2_verbose_logging
              builder.response :logger,
                               Rails.logger,
                               { bodies: true, formatter: Auth::OauthFaradayFormatter }
            end
            builder.request :url_encoded
            builder.adapter FinalDestination::FaradayAdapter
          end
          # All the data we need for the `info` and `credentials` auth hash
          # are obtained via the user info API, not the JWT. Using and verifying
          # the JWT can fail due to clock skew, so let's skip it completely.
          # https://github.com/zquestz/omniauth-google-oauth2/pull/392
          opts[:skip_jwt] = true
        end,
    }
    omniauth.provider :google_oauth2, options
  end

  def after_authenticate(auth_token, existing_account: nil)
    groups = provides_groups? ? raw_groups(auth_token.uid) : nil
    auth_token.extra[:raw_groups] = groups if groups

    result = super

    if groups
      result.associated_groups =
        groups.map { |group| group.with_indifferent_access.slice(:id, :name) }
    end

    result
  end

  def provides_groups?
    SiteSetting.google_oauth2_hd.present? && SiteSetting.google_oauth2_hd_groups &&
      SiteSetting.google_oauth2_hd_groups_service_account_admin_email.present? &&
      SiteSetting.google_oauth2_hd_groups_service_account_json.present?
  end

  private

  def raw_groups(uid)
    groups = []
    page_token = nil
    groups_url = "https://#{GROUPS_DOMAIN}#{GROUPS_PATH}"
    client = build_service_account_client
    return if client.nil?

    loop do
      params = { userKey: uid }
      params[:pageToken] = page_token if page_token

      response = client.get(groups_url, params: params, raise_errors: false)

      if response.status == 200
        response = response.parsed
        groups.push(*response["groups"])
        page_token = response["nextPageToken"]
        break if page_token.nil?
      else
        Rails.logger.error(
          "[Discourse Google OAuth2] failed to retrieve groups for #{uid} - status #{response.status}",
        )
        break
      end
    end

    groups
  end

  def build_service_account_client
    service_account_info = JSON.parse(SiteSetting.google_oauth2_hd_groups_service_account_json)

    payload = {
      iss: service_account_info["client_email"],
      aud: "#{OAUTH2_BASE_URL}/token",
      scope: GROUPS_SCOPE,
      iat: Time.now.to_i,
      exp: Time.now.to_i + 60,
      sub: SiteSetting.google_oauth2_hd_groups_service_account_admin_email,
    }
    headers = { "alg" => "RS256", "typ" => "JWT" }
    key = OpenSSL::PKey::RSA.new(service_account_info["private_key"])

    encoded_jwt = ::JWT.encode(payload, key, "RS256", headers)

    client =
      OAuth2::Client.new(
        SiteSetting.google_oauth2_client_id,
        SiteSetting.google_oauth2_client_secret,
        site: OAUTH2_BASE_URL,
      )

    token_response =
      client.request(
        :post,
        "/token",
        body: {
          grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
          assertion: encoded_jwt,
        },
        raise_errors: false,
      )

    if token_response.status != 200
      Rails.logger.error(
        "[Discourse Google OAuth2] failed to retrieve group fetch token - status #{token_response.status}",
      )
      return
    end

    OAuth2::AccessToken.from_hash(client, token_response.parsed)
  end
end
