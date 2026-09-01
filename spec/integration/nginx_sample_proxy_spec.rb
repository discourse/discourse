# frozen_string_literal: true

RSpec.describe "Nginx sample proxy" do
  before do
    skip "nginx not found on PATH" unless NginxTestProxy.available?

    rails_server = Capybara::Server.new(Capybara.app).boot
    @proxy = NginxTestProxy.new(upstream_port: rails_server.port).start
    SiteSetting.force_hostname = "127.0.0.1"
    SiteSetting.port = @proxy.port
  end

  after { @proxy&.stop }

  it "uses the sample config's special routes", :aggregate_failures do
    expect(@proxy.get("/favicon.ico").code).to eq("204")
    expect(@proxy.get("/backups/private.tar.gz").code).to eq("404")

    access_log = @proxy.access_log
    expect(@proxy.get("/srv/status").code).to eq("200")
    expect(@proxy.access_log).to eq(access_log)
  end

  it "routes dynamic requests through the @discourse fallback", :aggregate_failures do
    response = @proxy.get("/latest.json")

    expect(response).to be_a(Net::HTTPSuccess)
    expect(response["X-Nginx-Discourse-Fallback"]).to eq("true")
  end
end
