# frozen_string_literal: true

class DiscourseLti::LtiOmniauthStrategy
  include OmniAuth::Strategy

  # https://www.imsglobal.org/spec/security/v1p0/#openid_connect_launch_flow

  class CallbackError < StandardError
    attr_accessor :error, :error_reason, :error_uri

    def initialize(error, error_reason = nil, error_uri = nil)
      self.error = error
      self.error_reason = error_reason
      self.error_uri = error_uri
    end

    def message
      [error, error_reason, error_uri].compact.join(" | ")
    end
  end

  option :client_ids
  option :authorize_url
  option :platform_issuer_id
  option :platform_public_key

  # LTI authentication is only supported as a "third party initiated login"
  # i.e. all authentication must be started by the 'platform'
  def request_phase
    fail!(
      :third_party_only,
      StandardError.new("LTI authentication can only be initiated by the identity provider"),
    )
  end

  def other_phase
    methods = %i[get post]
    if on_initiate_path? && %i[get post].include?(request.request_method.downcase.to_sym)
      return initiate_phase
    end

    @app.call(env)
  end

  def initiate_phase
    setup_phase

    if cross_site_post?
      return(
        resubmit_as_samesite(:iss, :login_hint, :target_link_uri, :lti_message_hint, :client_id)
      )
    end

    iss = request.params["iss"]
    login_hint = request.params["login_hint"]
    target_link_uri = request.params["target_link_uri"]
    lti_message_hint = request.params["lti_message_hint"]
    client_id = request.params["client_id"]

    if !(iss.present? && login_hint.present? && target_link_uri.present?)
      return(
        fail! :missing_parameters,
              RuntimeError.new(
                "Missing parameters. Requires `iss`, `login_hint` and `target_link_uri`",
              )
      )
    end

    if iss != options.platform_issuer_id
      return(
        fail!(
          :invalid_issuer,
          RuntimeError.new(
            "Issuer does not match. Expected '#{options.platform_issuer_id}', got '#{iss}'.",
          ),
        )
      )
    end

    if client_id.present? && !options.client_ids.include?(client_id)
      # client_id is an optional parameter. If present, it must be correct
      return(
        fail!(
          :invalid_client_id,
          RuntimeError.new(
            "Client ID does not match. Expected one of '#{options.client_ids.join(",")}', got '#{client_id}'.",
          ),
        )
      )
    elsif !client_id.present? && options.client_ids.size > 1
      # We require it if multiple client_ids have been configured
      return(
        fail!(
          :missing_client_id,
          RuntimeError.new(
            "client_id parameter not passed, and multiple allowed client_ids are configured",
          ),
        )
      )
    elsif !client_id.present?
      client_id = options.client_ids.first
    end

    state = SecureRandom.hex
    nonce = SecureRandom.hex

    session["omniauth.state"] = state
    session["omniauth.nonce"] = nonce
    session["destination_url"] = target_link_uri

    params = {
      scope: "openid",
      response_type: "id_token",
      response_mode: "form_post",
      prompt: "none",
      client_id: client_id,
      redirect_uri: callback_url,
      login_hint: login_hint,
      state: state,
      nonce: nonce,
    }

    params[:lti_message_hint] = lti_message_hint if lti_message_hint

    redirect "#{options.authorize_url}?#{params.to_query}"
  end

  def callback_call
    return resubmit_as_samesite(:error, :state, :id_token) if cross_site_post?
    super
  end

  def callback_phase
    if error = request.params["error"]
      return(
        fail! error,
              CallbackError.new(
                request.params["error"],
                request.params["error_description"],
                request.params["error_uri"],
              )
      )
    elsif request.params["state"].to_s.empty?
      return(
        fail! :state_missing, StandardError.new("State parameter was not included in the callback")
      )
    elsif request.params["id_token"].to_s.empty?
      return(
        fail! :id_token_missing,
              StandardError.new("id_token parameter was not included in the callback")
      )
    elsif request.params["state"] != session["omniauth.state"]
      return(fail! :state_mismatch, StandardError.new("State parameter did not match the session"))
    elsif id_token_info["nonce"] != session["omniauth.nonce"]
      return(fail! :nonce_mismatch, StandardError.new("Nonce claim did not match the session"))
    elsif [*id_token_info["aud"]].length > 1 && !options.client_ids.include(id_token_info["azp"])
      # If the ID Token contains multiple audiences, the Tool SHOULD verify that an azp Claim is present;
      # If an azp (authorized party) Claim is present, the Tool SHOULD verify that its client_id is the Claim's value;
      return(
        fail! :azp_mismatch,
              StandardError.new(
                "azp claim invalid. Expected one of #{options.client_ids.join(",")}, received #{id_token_info["azp"]}",
              )
      )
    end

    super
  rescue ::JWT::DecodeError => e
    fail! :token_invalid, e
  end

  def on_auth_path?
    super || on_initiate_path?
  end

  def on_initiate_path?
    on_path?("#{path_prefix}/#{name}/initiate")
  end

  def cross_site_post?
    request.request_method.downcase.to_sym == :post && request.params["samesite"].nil?
  end

  def resubmit_as_samesite(*params)
    form_fields =
      params
        .filter_map do |param_name|
          next if request.params[param_name.to_s].nil?
          escaped_value = Rack::Utils.escape_html request.params[param_name.to_s]
          "<input type='hidden' name='#{param_name}' value='#{escaped_value}'/>"
        end
        .join("\n")

    response_headers = { "Content-Type" => "text/html; charset=UTF-8" }

    script_path = "/plugins/discourse-lti/javascripts/submit-on-load-lti.js"
    html = <<~HTML
      <html>
        <head>
          <script src="#{UrlHelper.absolute(script_path, GlobalSetting.cdn_url)}" nonce="#{ContentSecurityPolicy.try(:nonce_placeholder, response_headers)}"></script>
        </head>
        <body>
          <form method="post">
            <input type='hidden' name='samesite' value='true'/>
            #{form_fields}
            <noscript>
              <input type="submit" value="Continue"/>
            </noscript>
          </form>
        </body>
      </html>
    HTML

    r = Rack::Response.new(html, 200, response_headers)
    r.finish
  end

  def id_token_info
    @id_token_info ||= decode_token(request.params["id_token"])
  end

  def decode_token(token)
    payload, header =
      ::JWT.decode(
        request.params["id_token"],
        public_key,
        true,
        {
          algorithm: "RS256",
          verify_expiration: true,
          verify_not_before: true,
          iss: options.platform_issuer_id,
          verify_iss: true,
          aud: options.client_ids,
          verify_aud: true,
        },
      )

    payload
  end

  def raw_public_key
    raw = options.platform_public_key
    if raw.start_with?("-----BEGIN")
      raw
    else
      "-----BEGIN PUBLIC KEY-----\n#{raw}\n-----END PUBLIC KEY-----"
    end
  end

  def public_key
    @public_key ||= OpenSSL::PKey::RSA.new raw_public_key
  end

  uid { id_token_info["sub"] }

  info do
    {
      name: id_token_info["name"],
      email: id_token_info["email"],
      first_name: id_token_info["given_name"],
      last_name: id_token_info["family_name"],
      nickname: id_token_info["preferred_username"],
      image: id_token_info["picture"],
    }
  end

  extra { { raw_info: id_token_info, id_token: request.params["id_token"] } }

  def callback_url
    full_host + script_name + callback_path
  end
end
