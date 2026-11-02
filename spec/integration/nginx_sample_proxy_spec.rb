# frozen_string_literal: true

require "capybara/rails"

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
    expect(@proxy.get("/srv/status").code).to eq("200")
    expect(@proxy.get("/backups/private.tar.gz").code).to eq("404")

    backup_request = "GET /backups/private.tar.gz HTTP/1.1"
    wait_for(timeout: 5) { @proxy.access_log.include?(backup_request) }
    expect(@proxy.access_log.lines).to contain_exactly(a_string_including(backup_request))
  end

  it "routes dynamic requests through the @discourse fallback", :aggregate_failures do
    response = @proxy.get("/latest.json")

    expect(response).to be_a(Net::HTTPSuccess)
    expect(response["X-Nginx-Discourse-Fallback"]).to eq("true")
  end
end
