# frozen_string_literal: true

RSpec.describe OAuth2FaradayFormatter do
  subject(:formatter) { described_class.new(logger:, options: {}) }

  let(:logger) { instance_double(Logger) }
  let(:messages) { [] }

  before { allow(logger).to receive(:warn) { |message| messages << message } }

  def faraday_env(method:, url:, headers:, body:, status: nil)
    OpenStruct.new(method:, url: URI(url), request_headers: headers, body:, status:)
  end

  it "redacts credentials from request metadata without mutating the request" do
    basic_credentials = "Basic #{Base64.strict_encode64("client:client-secret")}"
    request_body = {
      client_secret: "client-secret",
      code: "authorization-code",
      access_token: "access-token",
    }.to_json
    headers = {
      "Authorization" => basic_credentials,
      "X-Refresh-Token" => "refresh-token",
      "Accept" => "application/json",
    }
    url =
      "https://id.example.com/token?code=authorization-code&client_secret=client-secret&request_id=request-123"
    env = faraday_env(method: :post, url:, headers:, body: request_body)

    formatter.request(env)

    message = messages.join
    expect(message).to include("request_id=request-123", "Accept", "application/json", "[FILTERED]")
    expect(message).not_to include(
      basic_credentials,
      "client-secret",
      "authorization-code",
      "access-token",
      "refresh-token",
    )
    expect(env.url.to_s).to eq(url)
    expect(env.request_headers).to eq(headers)
    expect(env.body).to eq(request_body)
  end

  it "redacts URL userinfo and rejects invalid URLs" do
    url = "https://client:secret@id.example.com/token?request_id=request-123"

    redacted_url = OAuth2LogRedactor.url(url)

    expect(redacted_url).to eq("https://[FILTERED]@id.example.com/token?request_id=request-123")
    expect(redacted_url).not_to include("client", "secret")
    expect(OAuth2LogRedactor.url("https://invalid.example.com/%zz")).to eq("[FILTERED]")
  end

  it "omits JSON, form-encoded, and malformed response bodies and redacts bearer credentials" do
    bearer_credentials = "Bearer access-token"
    response_bodies = [
      {
        access_token: "access-token",
        refresh_token: "refresh-token",
        id_token: "id-token",
      }.to_json,
      URI.encode_www_form(access_token: "access-token", refresh_token: "refresh-token"),
      "malformed access-token response",
    ]

    response_bodies.each do |body|
      env =
        faraday_env(
          method: :post,
          url: "https://id.example.com/token?access_token=access-token&request_id=request-123",
          headers: {
            "Authorization" => bearer_credentials,
            "Accept" => "application/json",
          },
          body:,
          status: 200,
        )

      formatter.response(env)
    end

    message = messages.join
    expect(message).to include("response status 200", "request_id=request-123", "[OMITTED]")
    expect(message).not_to include(
      bearer_credentials,
      "access-token",
      "refresh-token",
      "id-token",
      "malformed",
    )
  end
end
