# frozen_string_literal: true

class Auth::GoogleOAuth2Authenticator < Auth::ManagedAuthenticator
  GROUPS_SCOPE ||= "admin.directory.group.readonly"
  GROUPS_URL ||= "https://admin.googleapis.com/admin/directory/v1/groups"

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

        if SiteSetting.google_oauth2_hd_groups.present?
          strategy.options[:include_granted_scopes] = true
        end
      }
    }
    omniauth.provider :google_oauth2, options
  end

  def after_authenticate(auth_token, existing_account: nil)
    auth_result = super
    domain = auth_token[:extra][:raw_info][:hd]
    session = auth_token[:session]

    if should_get_groups_for_domain(domain)
      auth_result.extra_data[:provider_domain] = domain

      if !token_has_groups_scope(session) && !secondary_authorization_response(session)
        auth_result.secondary_authorization_url = secondary_authorization_url
        return auth_result
      end

      auth_result.associated_groups = get_groups(auth_token)
    end

    auth_result
  end

  def get_groups(auth_token)
    groups = []
    page_token = ""

    until page_token.nil? do
      response_json = request_groups(auth_token, page_token)
      if (groups_json = response_json['groups']).present?
        groups.push(*groups_json.map { |g| g['name'] })
      end
      page_token = response_json['nextPageToken'].present? ? response_json['nextPageToken'] : nil
    end

    groups
  end

  def secondary_authorization_url
    "#{Discourse.base_url}/auth/#{name}?state=secondary&scope=#{GROUPS_SCOPE}"
  end

  protected

  def request_groups(auth_token, page_token)
    connection = Excon.new(GROUPS_URL)

    query = {
      userKey: auth_token[:uid]
    }
    query[:pageToken] = page_token if page_token.present?

    response = connection.get(
      headers: {
        'Authorization' => "Bearer #{auth_token[:credentials][:token]}",
        'Accept' => 'application/json'
      },
      query: query
    )

    if response.status == 200
      JSON.parse(response.body)
    else
      raise Discourse::InvalidAccess
    end
  end

  def should_get_groups_for_domain(domain)
    return false if !domain
    SiteSetting.google_oauth2_hd_groups.split('|').include?(domain)
  end

  def response_parameters(session)
    req = session.instance_variable_get(:@req)
    req.env['QUERY_STRING'] && Rack::Utils.parse_query(req.env['QUERY_STRING'], '&')
  end

  def secondary_authorization_response(session)
    params = response_parameters(session)
    params && params['state'] === 'secondary'
  end

  def token_has_groups_scope(session)
    # scope returned in response will include all scopes of token in incremental authorization.
    # see https://developers.google.com/identity/protocols/oauth2/web-server#incrementalAuth
    # Alternate token scope check (dev only): https://www.googleapis.com/oauth2/v3/tokeninfo

    params = response_parameters(session)
    params && params["scope"].present? && params["scope"].include?(GROUPS_SCOPE)
  end
end
