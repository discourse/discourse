# frozen_string_literal: true

require "json"
require "securerandom"
require_relative "../nginx/support/nginx_executable"
require_relative "../nginx/support/nginx_harness"
require_relative "../nginx/support/rails_upstream"

RSpec.describe "Nginx sample proxy" do
  fab!(:topic)

  let(:upstream) { Nginx::Support::RailsUpstream.shared }
  let(:harness) do
    Nginx::Support::NginxHarness.new(
      upstream: upstream,
      public_path: Rails.root.join("frontend/discourse/dist"),
    )
  end
  let(:discovery) { PageObjects::Pages::Discovery.new }
  let(:smuggled_headers) do
    {
      "X-Sendfile-Type" => "spoofed-sendfile",
      "X-Accel-Mapping" => "/tmp/=/downloads/",
      "Client-Ip" => "203.0.113.10",
    }
  end
  let(:spoofed_proxy_headers) do
    { "X-Forwarded-For" => "198.51.100.7", "X-Forwarded-Proto" => "https" }
  end

  before do
    skip "nginx not found on PATH" unless Nginx::Support::NginxExecutable.available?

    harness.start
    SiteSetting.force_hostname = "localhost"
    SiteSetting.port = harness.listen_port
  end

  after { harness.stop }

  it "proxies requests safely through nginx", :aggregate_failures do
    request_id = SecureRandom.uuid
    response =
      harness.get(
        "/missing-path",
        headers: probe_headers(request_id).merge(smuggled_headers).merge(spoofed_proxy_headers),
      )

    request = upstream.probe.request(request_id)
    expect(response.code).to eq("404")
    expect(request).to include(method: "GET", path: "/missing-path", remote_addr: "127.0.0.1")
    expect_proxy_headers(request)
    expect_acceleration_headers_stripped(request)
    expect(harness.nginx_access_log).to include('"GET /missing-path HTTP/1.1"')

    status_request_id = SecureRandom.uuid
    access_log_before = harness.nginx_access_log
    status_response =
      harness.get(
        "/srv/status",
        headers:
          probe_headers(status_request_id).merge(smuggled_headers).merge(spoofed_proxy_headers),
      )

    status_request = upstream.probe.request(status_request_id)
    expect(status_response.code).to eq("200")
    expect(status_request).to include(method: "GET", path: "/srv/status")
    expect_proxy_headers(status_request)
    expect_acceleration_headers_stripped(status_request)
    expect(harness.nginx_access_log).to eq(access_log_before)

    asset_request_id = SecureRandom.uuid
    asset_response =
      harness.get(
        "/svg-sprite/#{SecureRandom.hex(8)}.js",
        headers: {
          **probe_headers(asset_request_id),
          "X-Nginx-Test-Inject-Response-Headers" => "true",
        },
      )

    expect(asset_response.code).to eq("404")
    expect(upstream.probe.request(asset_request_id)[:path]).to start_with("/svg-sprite/")
    expect(asset_response["Set-Cookie"]).to be_nil
    expect(asset_response["X-Discourse-Username"]).to be_nil
    expect(asset_response["X-Runtime"]).to be_nil
  end

  it "lets the user browse Discourse through nginx" do
    visit("http://localhost:#{harness.listen_port}/latest")

    expect(discovery.topic_list).to have_topic(topic)
  end

  def probe_headers(request_id)
    { "Host" => "localhost:#{harness.listen_port}", "X-Nginx-Test-Id" => request_id }
  end

  def expect_proxy_headers(request)
    expect(request[:headers]).to include(
      "HTTP_HOST" => "localhost:#{harness.listen_port}",
      "HTTP_X_FORWARDED_FOR" => "127.0.0.1",
      "HTTP_X_FORWARDED_PROTO" => "https",
    )
    expect(request[:headers]["HTTP_X_REQUEST_START"]).to match(/\At=\d+(?:\.\d+)?\z/)
  end

  def expect_acceleration_headers_stripped(request)
    expect(request[:headers]).not_to include(
      "HTTP_X_SENDFILE_TYPE",
      "HTTP_X_ACCEL_MAPPING",
      "HTTP_CLIENT_IP",
    )
  end
end
