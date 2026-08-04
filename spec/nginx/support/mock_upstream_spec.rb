# frozen_string_literal: true

require "json"
require "stringio"
require_relative "mock_upstream"

RSpec.describe Nginx::Support::MockUpstream do
  subject(:upstream) { described_class.new }

  it "echoes Rack headers with stable casing for common acronyms" do
    _status, _headers, body =
      upstream.call(
        request_env(
          "HTTP_ETAG" => "tag",
          "HTTP_X_REAL_IP" => "127.0.0.1",
          "HTTP_X_REQUEST_ID" => "request-id",
        ),
      )

    payload = JSON.parse(body.join)

    expect(payload["headers"]).to include(
      "ETag" => "tag",
      "X-Real-IP" => "127.0.0.1",
      "X-Request-ID" => "request-id",
    )
    expect(payload["headers"]).not_to have_key("X-Real-Ip")
    expect(payload["headers"]).not_to have_key("X-Request-Id")
  end

  it "preserves original header names captured before Rack env conversion" do
    _status, _headers, body =
      upstream.call(
        request_env(
          described_class::ORIGINAL_HEADER_NAMES_ENV => {
            "HTTP_X_REQUEST_ID" => "x-request-id",
          },
          "HTTP_X_REQUEST_ID" => "request-id",
        ),
      )

    payload = JSON.parse(body.join)

    expect(payload["headers"]).to include("x-request-id" => "request-id")
    expect(payload["headers"]).not_to have_key("X-Request-ID")
  end

  it "uses the same header casing for shaped response headers" do
    _status, headers, _body = upstream.call(request_env("HTTP_X_MOCK_HEADER_ETAG" => "tag"))

    expect(headers["ETag"]).to eq("tag")
    expect(headers).not_to have_key("Etag")
  end

  def request_env(headers = {})
    {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/",
      "QUERY_STRING" => "",
      "rack.input" => StringIO.new(""),
    }.merge(headers)
  end
end
