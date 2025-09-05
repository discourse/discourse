# frozen_string_literal: true

require "webrick"

module SsoHelpers
  def build_sso_payload(return_url)
    secret = SiteSetting.discourse_connect_provider_secrets.split("|")[1]
    nonce = SecureRandom.hex

    payload = "nonce=#{CGI.escape(nonce)}&return_sso_url=#{CGI.escape(return_url)}"
    sso = Base64.strict_encode64(payload)
    sig = OpenSSL::HMAC.hexdigest("sha256", secret, sso)

    [sso, sig]
  end

  def setup_test_sso_server(user:, sso_secret:, sso_port:, sso_url:)
    @server =
      WEBrick::HTTPServer.new(
        Port: sso_port,
        Logger: WEBrick::Log.new(File.open(File::NULL, "w")),
        AccessLog: [],
      )

    @server.mount_proc "/sso" do |req, res|
      decoded = Base64.decode64(req.query["sso"])
      params = Rack::Utils.parse_query(decoded)

      response_sso = DiscourseConnectBase.new
      response_sso.nonce = params["nonce"]
      response_sso.sso_secret = sso_secret
      response_sso.external_id = "foo-bar"
      response_sso.email = user.email
      response_sso.username = user.username

      res.status = 302
      res["Location"] = "#{params["return_sso_url"]}?#{response_sso.payload}"
    end

    @server_thread = Thread.new { @server.start }

    sleep 0.1 until server_responding?(sso_url)
  end

  def shutdown_test_sso_server
    @server&.shutdown
    @server_thread&.kill
  end

  def server_responding?(sso_url)
    Net::HTTP.get_response(URI(sso_url))
    true
  rescue StandardError
    false
  end
end
