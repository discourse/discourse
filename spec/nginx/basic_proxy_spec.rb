# frozen_string_literal: true

require "json"
require_relative "support/nginx_harness"

RSpec.describe "nginx.sample.conf basic proxying" do # rubocop:disable RSpec/DescribeClass
  let(:harness) { Nginx::Support::NginxHarness.new }

  before { harness.start }
  after { harness.stop }

  it "forwards a missing path through @discourse with the proxy headers intact" do
    response = harness.get("/missing-path")

    expect(response.code).to eq("200")

    payload = JSON.parse(response.body)
    expect(payload["method"]).to eq("GET")
    expect(payload["path"]).to eq("/missing-path")
    expect(payload["headers"]).to include(
      "Host" => "127.0.0.1:#{harness.listen_port}",
      "X-Real-IP" => "127.0.0.1",
      "X-Forwarded-For" => "127.0.0.1",
      "X-Forwarded-Proto" => "http",
    )
    expect(payload["headers"]).not_to have_key("X-Sendfile-Type")
    expect(payload["headers"]).not_to have_key("X-Accel-Mapping")
    expect(payload["headers"]).not_to have_key("Client-Ip")
    expect(payload["headers"]["X-Request-Start"]).to match(/\At=\d+(?:\.\d+)?\z/)
  end

  it "forwards /srv/status directly to the upstream with the proxy headers intact" do
    response = harness.get("/srv/status")

    expect(response.code).to eq("200")

    payload = JSON.parse(response.body)
    expect(payload["method"]).to eq("GET")
    expect(payload["path"]).to eq("/srv/status")
    expect(payload["headers"]).to include(
      "Host" => "127.0.0.1:#{harness.listen_port}",
      "X-Real-IP" => "127.0.0.1",
      "X-Forwarded-For" => "127.0.0.1",
      "X-Forwarded-Proto" => "http",
    )
    expect(payload["headers"]).not_to have_key("X-Sendfile-Type")
    expect(payload["headers"]).not_to have_key("X-Accel-Mapping")
    expect(payload["headers"]).not_to have_key("Client-Ip")
    expect(payload["headers"]["X-Request-Start"]).to match(/\At=\d+(?:\.\d+)?\z/)
  end
end
