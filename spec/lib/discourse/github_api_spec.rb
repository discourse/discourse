# frozen_string_literal: true

RSpec.describe Discourse::GithubApi do
  subject(:client) { described_class.for(token:) }

  let(:token) { "gh_token_abc" }

  before { described_class.reset_clients! }

  def stub_gh(path, status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
    stub_request(:get, "https://api.github.com#{path}").to_return(status:, body:, headers:)
  end

  describe "#get" do
    it "returns a plain string-keyed Hash (not Sawyer)" do
      stub_gh(
        "/repos/discourse/discourse/pulls/1",
        body: { "title" => "Hi", "base" => { "ref" => "main" } }.to_json,
      )

      result = client.get("/repos/discourse/discourse/pulls/1")

      expect(result).to be_a(Hash)
      expect(result["base"]["ref"]).to eq("main")
      expect(result.dig("base", "ref")).to eq("main")
    end

    it "returns an Array for list endpoints" do
      stub_gh(
        "/repos/discourse/discourse/pulls/1/reviews",
        body: [{ "state" => "APPROVED" }].to_json,
      )
      expect(client.get("/repos/discourse/discourse/pulls/1/reviews")).to eq(
        [{ "state" => "APPROVED" }],
      )
    end

    it "sends a Bearer Authorization header when a token is configured" do
      stub =
        stub_request(:get, "https://api.github.com/x").with(
          headers: {
            "Authorization" => "Bearer #{token}",
          },
        ).to_return(status: 200, body: "{}")
      client.get("/x")
      expect(stub).to have_been_requested
    end

    it "sends no Authorization header when unauthenticated" do
      anon = described_class.for(token: nil)
      stub = stub_request(:get, "https://api.github.com/x").to_return(status: 200, body: "{}")
      anon.get("/x")
      expect(stub).to have_been_requested
      expect(WebMock).not_to have_requested(:get, "https://api.github.com/x").with(
        headers: {
          "Authorization" => /.+/,
        },
      )
    end
  end

  describe "rate limiting" do
    it "short-circuits with RateLimited (no HTTP) while backing off" do
      GithubRateLimit.note_rate_limit(token:, retry_after: 60)
      expect { client.get("/x") }.to raise_error(described_class::RateLimited)
      expect(a_request(:get, "https://api.github.com/x")).not_to have_been_made
    end

    it "records a backoff and raises on a 403 rate-limit response" do
      stub_gh(
        "/x",
        status: 403,
        headers: {
          "x-ratelimit-remaining" => "0",
          "x-ratelimit-reset" => 10.minutes.from_now.to_i.to_s,
        },
      )
      expect { client.get("/x") }.to raise_error(described_class::RateLimited)
      expect(GithubRateLimit.backing_off?(token)).to eq(true)
    end

    it "proactively backs off when a 200 reports the budget is exhausted" do
      stub_gh(
        "/x",
        headers: {
          "Content-Type" => "application/json",
          "x-ratelimit-remaining" => "0",
          "x-ratelimit-reset" => 10.minutes.from_now.to_i.to_s,
        },
      )
      client.get("/x")
      expect(GithubRateLimit.backing_off?(token)).to eq(true)
    end
  end

  describe "error mapping" do
    it "raises NotFound on 404" do
      stub_gh("/x", status: 404)
      expect { client.get("/x") }.to raise_error(described_class::NotFound)
    end

    it "raises Unauthorized on 401" do
      stub_gh("/x", status: 401)
      expect { client.get("/x") }.to raise_error(described_class::Unauthorized)
    end

    it "raises a non-rate-limit error on a 403 with budget remaining (no backoff)" do
      stub_gh("/x", status: 403, headers: { "x-ratelimit-remaining" => "57" })
      expect { client.get("/x") }.to raise_error(described_class::Error) do |e|
        expect(e).not_to be_a(described_class::RateLimited)
      end
      expect(GithubRateLimit.backing_off?(token)).to eq(false)
    end

    it "maps Faraday timeouts/connection failures to its own Error" do
      stub_request(:get, "https://api.github.com/x").to_timeout
      expect { client.get("/x") }.to raise_error(described_class::Error)
    end
  end

  describe "ETag conditional requests" do
    it "stores the ETag and serves the cached body on a 304 (no rate-limit cost)" do
      stub_request(:get, "https://api.github.com/x").to_return(
        status: 200,
        body: { "n" => 1 }.to_json,
        headers: {
          "Content-Type" => "application/json",
          "ETag" => 'W/"abc"',
        },
      )
      expect(client.get("/x")).to eq({ "n" => 1 })

      stub_request(:get, "https://api.github.com/x").with(
        headers: {
          "If-None-Match" => 'W/"abc"',
        },
      ).to_return(status: 304, body: "")
      expect(client.get("/x")).to eq({ "n" => 1 })
    end
  end

  describe "#raw_get" do
    it "returns the raw body as a String" do
      stub_request(:get, "https://raw.githubusercontent.com/d/d/main/x.rb").to_return(
        status: 200,
        body: "puts 1",
      )
      expect(client.raw_get("https://raw.githubusercontent.com/d/d/main/x.rb")).to eq("puts 1")
    end
  end

  describe "host allowlist" do
    it "refuses to call (and leak the token to) a non-GitHub absolute URL" do
      expect { client.get("https://evil.example.com/steal") }.to raise_error(ArgumentError)
      expect { client.raw_get("https://evil.example.com/steal") }.to raise_error(ArgumentError)
      expect(a_request(:get, "https://evil.example.com/steal")).not_to have_been_made
    end
  end

  describe "#post" do
    it "sends a JSON body" do
      stub =
        stub_request(:post, "https://api.github.com/repos/d/d/issues/1/comments").with(
          body: { body: "hi" }.to_json,
        ).to_return(status: 201, body: "{}")
      client.post("/repos/d/d/issues/1/comments", { body: "hi" })
      expect(stub).to have_been_requested
    end
  end
end
