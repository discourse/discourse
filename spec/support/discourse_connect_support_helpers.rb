# frozen_string_literal: true

require "webrick"

module DiscourseConnectHelpers
  def self.provider_port=(port)
    @provider_port = port
  end

  def self.provider_port
    @provider_port
  end

  def build_discourse_connect_payload(return_url = nil, data = {})
    if data.empty?
      secret = SiteSetting.discourse_connect_provider_secrets.split("|")[1]
      nonce = SecureRandom.hex

      payload = "nonce=#{CGI.escape(nonce)}&return_sso_url=#{CGI.escape(return_url)}"
      sso = Base64.strict_encode64(payload)
      sig = OpenSSL::HMAC.hexdigest("sha256", secret, sso)
    else
      secret = SiteSetting.discourse_connect_secret
      nonce = data[:nonce] || SecureRandom.hex

      response_sso = DiscourseConnectBase.new
      response_sso.sso_secret = secret
      response_sso.nonce = nonce

      response_sso.external_id = data[:external_id] if data[:external_id]
      response_sso.email = data[:email] if data[:email]
      response_sso.username = data[:username] if data[:username]
      response_sso.name = data[:name] if data[:name]
      response_sso.admin = data[:admin] if data.key?(:admin)
      response_sso.moderator = data[:moderator] if data.key?(:moderator)
      response_sso.add_groups = data[:add_groups] if data[:add_groups]
      response_sso.remove_groups = data[:remove_groups] if data[:remove_groups]
      response_sso.groups = data[:groups] if data[:groups]

      if data[:custom_fields]
        data[:custom_fields].each { |key, value| response_sso.custom_fields[key] = value }
      end

      full_payload = response_sso.payload
      parsed = CGI.parse(full_payload)
      sso = parsed["sso"][0]
      sig = parsed["sig"][0]
    end

    [sso, sig]
  end

  def setup_test_discourse_connect_server(user:, sso_secret:)
    raise "Provider port not set" unless DiscourseConnectHelpers.provider_port

    before_next_spec { shutdown_test_discourse_connect_server }

    @server =
      WEBrick::HTTPServer.new(
        Port: DiscourseConnectHelpers.provider_port,
        Logger: WEBrick::Log.new(File.open(File::NULL, "w")),
        AccessLog: [],
        BindAddress: "localhost",
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

    until server_responding?("http://localhost:#{DiscourseConnectHelpers.provider_port}/sso")
      sleep 0.1
    end

    DiscourseConnectHelpers.provider_port
  end

  def shutdown_test_discourse_connect_server
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
