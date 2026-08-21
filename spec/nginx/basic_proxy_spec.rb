# frozen_string_literal: true

require "json"
require "securerandom"
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

  # A client-supplied X-Forwarded-For that must NOT be trusted: the sample
  # conf sets X-Forwarded-For to the end-user IP ($remote_addr), overwriting
  # any inbound value, so a spoofed forwarded chain cannot get through.
  let(:spoofed_proxy_headers) do
    { "X-Forwarded-For" => "198.51.100.7", "X-Forwarded-Proto" => "https" }
  end

  before { harness.start }
  after { harness.stop }

  it "forwards a missing path through @discourse with the proxy headers intact" do
    response = harness.get("/missing-path", headers: smuggled_headers.merge(spoofed_proxy_headers))

    expect(response.code).to eq("200")

    payload = JSON.parse(response.body)
    expect(payload["method"]).to eq("GET")
    expect(payload["path"]).to eq("/missing-path")
    expect(payload["headers"]).to include(
      "Host" => "127.0.0.1:#{harness.listen_port}",
      "X-Real-IP" => "127.0.0.1",
      # Spoofed inbound XFF (198.51.100.7) is overwritten with the real
      # end-user IP, not appended to.
      "X-Forwarded-For" => "127.0.0.1",
      "X-Forwarded-Proto" => "https",
    )
    expect_acceleration_headers_stripped(payload["headers"])
    expect(payload["headers"]["X-Request-Start"]).to match(/\At=\d+(?:\.\d+)?\z/)
    expect(harness.nginx_access_log).to include('"GET /missing-path HTTP/1.1"')
  end

  it "forwards /srv/status directly to the upstream with the proxy headers intact" do
    access_log_before = harness.nginx_access_log
    response = harness.get("/srv/status", headers: smuggled_headers.merge(spoofed_proxy_headers))

    expect(response.code).to eq("200")

    payload = JSON.parse(response.body)
    expect(payload["method"]).to eq("GET")
    expect(payload["path"]).to eq("/srv/status")
    expect(payload["headers"]).to include(
      "Host" => "127.0.0.1:#{harness.listen_port}",
      "X-Real-IP" => "127.0.0.1",
      # Spoofed inbound XFF is overwritten with the real end-user IP.
      "X-Forwarded-For" => "127.0.0.1",
      "X-Forwarded-Proto" => "https",
    )
    expect_acceleration_headers_stripped(payload["headers"])
    expect(payload["headers"]["X-Request-Start"]).to match(/\At=\d+(?:\.\d+)?\z/)
    expect(harness.nginx_access_log).to eq(access_log_before)
  end

  it "strips sensitive response headers from the cached asset route" do
    # The cached asset location (svg-sprite/letter_avatar/user_avatar/...)
    # proxy_hide_header's Set-Cookie, X-Discourse-Username and X-Runtime so
    # a cached upstream response can never leak them to other clients. Ask
    # the mock upstream to emit all three and assert nginx removes them.
    # A unique path keeps this a fresh cache MISS so the assertion isn't
    # masked by a previously cached response.
    leaky_headers = {
      "X-Mock-Header-Set-Cookie" => "_t=secret-session; path=/",
      "X-Mock-Header-X-Discourse-Username" => "admin",
      "X-Mock-Header-X-Runtime" => "0.123456",
    }
    path = "/svg-sprite/#{SecureRandom.hex(8)}.js"
    response = harness.get(path, headers: leaky_headers)

    expect(response.code).to eq("200")
    # Confirm the request actually reached the upstream (the mock echoes the
    # request as JSON), so the headers below are absent because nginx hid
    # them -- not because some other handler served this path.
    expect(JSON.parse(response.body)["path"]).to eq(path)
    expect(response["Set-Cookie"]).to be_nil
    expect(response["X-Discourse-Username"]).to be_nil
    expect(response["X-Runtime"]).to be_nil
  end

  def expect_acceleration_headers_stripped(headers)
    expect(headers).not_to have_key("X-Sendfile-Type")
    expect(headers).not_to have_key("X-Accel-Mapping")
    expect(headers).not_to have_key("Client-Ip")
  end
end
