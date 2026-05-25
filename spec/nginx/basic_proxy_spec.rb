# frozen_string_literal: true

require "json"
require_relative "support/nginx_harness"

RSpec.describe "nginx.sample.conf basic proxying" do # rubocop:disable RSpec/DescribeClass
  let(:harness) { Nginx::Support::NginxHarness.new }
  let(:smuggled_headers) do
    {
      "X-Sendfile-Type" => "spoofed-sendfile",
      "X-Accel-Mapping" => "/tmp/=/downloads/",
      "Client-Ip" => "203.0.113.10",
    }
  end

  let(:existing_proxy_headers) do
    { "X-Forwarded-For" => "198.51.100.7", "X-Forwarded-Proto" => "https" }
  end

  before { harness.start }
  after { harness.stop }

  it "forwards a missing path through @discourse with the proxy headers intact" do
    response = harness.get("/missing-path", headers: smuggled_headers.merge(existing_proxy_headers))

    expect(response.code).to eq("200")

    payload = JSON.parse(response.body)
    expect(payload["method"]).to eq("GET")
    expect(payload["path"]).to eq("/missing-path")
    expect(payload["headers"]).to include(
      "Host" => "127.0.0.1:#{harness.listen_port}",
      "X-Real-IP" => "127.0.0.1",
      "X-Forwarded-For" => "198.51.100.7, 127.0.0.1",
      "X-Forwarded-Proto" => "https",
    )
    expect_acceleration_headers_stripped(payload["headers"])
    expect(payload["headers"]["X-Request-Start"]).to match(/\At=\d+(?:\.\d+)?\z/)
    expect(harness.nginx_access_log).to include('"GET /missing-path HTTP/1.1"')
  end

  it "forwards /srv/status directly to the upstream with the proxy headers intact" do
    access_log_before = harness.nginx_access_log
    response = harness.get("/srv/status", headers: smuggled_headers)

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
    expect_acceleration_headers_stripped(payload["headers"])
    expect(payload["headers"]["X-Request-Start"]).to match(/\At=\d+(?:\.\d+)?\z/)
    expect(harness.nginx_access_log).to eq(access_log_before)
  end

  def expect_acceleration_headers_stripped(headers)
    expect(headers).not_to have_key("X-Sendfile-Type")
    expect(headers).not_to have_key("X-Accel-Mapping")
    expect(headers).not_to have_key("Client-Ip")
  end
end
