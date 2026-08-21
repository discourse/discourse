# frozen_string_literal: true

RSpec.describe "Nginx sample proxy" do
  before do
    skip "nginx not found on PATH" unless NginxTestProxy.available?

    @proxy = NginxTestProxy.new(upstream_port: page.server.port).start
    page.configure do |config|
      @original_app_host = config.app_host
      config.app_host = @proxy.url
    end
    SiteSetting.force_hostname = "127.0.0.1"
    SiteSetting.port = @proxy.port
  end

  after do
    page.configure { |config| config.app_host = @original_app_host }
    @proxy&.stop
  end

  it "uses the sample config's special routes", :aggregate_failures do
    expect(@proxy.get("/favicon.ico").code).to eq("204")
    expect(@proxy.get("/backups/private.tar.gz").code).to eq("404")

    access_log = @proxy.access_log
    expect(@proxy.get("/srv/status").code).to eq("200")
    expect(@proxy.access_log).to eq(access_log)
  end

  it "lets the browser reach Rails through nginx", allow_network: "127.0.0.1" do
    visit("/srv/status")

    expect(page).to have_content("ok")
  end
end
