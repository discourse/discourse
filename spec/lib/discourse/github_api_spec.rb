# frozen_string_literal: true

RSpec.describe Discourse::GithubApi do
  subject(:client) { described_class.for(token:) }

  let(:token) { "gh_token_abc" }

  before { described_class.reset_clients! }

  def stub_gh(path, status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
    stub_request(:get, "https://api.github.com#{path}").to_return(status:, body:, headers:)
  end

  def stub_redirect(from, to, status: 301, method: :get, headers: {})
    stub_request(method, "https://api.github.com#{from}").to_return(
      status:,
      headers: {
        "Location" => to,
        **headers,
      },
    )
  end

  def exhausted_rate_limit_headers
    { "x-ratelimit-remaining" => "0", "x-ratelimit-reset" => 10.minutes.from_now.to_i.to_s }
  end

  describe "#get" do
    it "returns the parsed JSON" do
      stub_gh("/repos/d/d/pulls/1", body: { "base" => { "ref" => "main" } }.to_json)
      expect(client.get("/repos/d/d/pulls/1")).to eq({ "base" => { "ref" => "main" } })
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
      stub_gh("/x", status: 403, headers: exhausted_rate_limit_headers)
      expect { client.get("/x") }.to raise_error(described_class::RateLimited)
      expect(GithubRateLimit.backing_off?(token)).to eq(true)
    end

    it "proactively backs off when a 200 reports the budget is exhausted" do
      stub_gh("/x", headers: exhausted_rate_limit_headers)
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

    it "raises a non-rate-limit error on a 403 with budget remaining" do
      stub_gh("/x", status: 403, headers: { "x-ratelimit-remaining" => "57" })
      expect { client.get("/x") }.to raise_error(described_class::Error) do |e|
        expect(e).not_to be_a(described_class::RateLimited)
      end
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

  describe "redirects" do
    it "follows a renamed repo's redirect with the token and params" do
      stub_redirect("/repos/old/name/branches?per_page=1", "/repositories/42/branches")
      stub =
        stub_request(:get, "https://api.github.com/repositories/42/branches?per_page=1").with(
          headers: {
            "Authorization" => "Bearer #{token}",
          },
        ).to_return(status: 200, body: "[]")

      expect(client.get("/repos/old/name/branches", per_page: 1)).to eq([])
      expect(stub).to have_been_requested.once
    end

    it "keeps the method and body" do
      stub_redirect(
        "/repos/old/name/issues/1/comments",
        "/repositories/42/issues/1/comments",
        status: 307,
        method: :post,
      )
      stub =
        stub_request(:post, "https://api.github.com/repositories/42/issues/1/comments").with(
          body: { body: "hi" }.to_json,
        ).to_return(status: 201, body: "{}")

      client.post("/repos/old/name/issues/1/comments", { body: "hi" })
      expect(stub).to have_been_requested
    end

    it "gives up after too many redirects" do
      (0..described_class::MAX_REDIRECTS).each { |i| stub_redirect("/#{i}", "/#{i + 1}") }

      expect { client.get("/0") }.to raise_error(described_class::Error, /redirect limit/)
    end

    it "raises when the redirect has no Location" do
      stub_gh("/x", status: 301)

      expect { client.get("/x") }.to raise_error(described_class::Error) do |e|
        expect(e.status).to eq(301)
      end
    end

    it "raises its own Error on a malformed Location" do
      stub_redirect("/x", "/not a valid path")

      expect { client.get("/x") }.to raise_error(described_class::Error, /Invalid/)
    end

    it "stops on a redirect that exhausts the rate limit" do
      stub_redirect("/x", "/y", headers: exhausted_rate_limit_headers)

      expect { client.get("/x") }.to raise_error(described_class::RateLimited)
      expect(a_request(:get, "https://api.github.com/y")).not_to have_been_made
    end
  end

  describe "host allowlist" do
    it "refuses to call (and leak the token to) a non-GitHub URL" do
      expect { client.get("https://evil.example.com/steal") }.to raise_error(described_class::Error)
      expect { client.get("http://api.github.com/x") }.to raise_error(described_class::Error)
      expect(a_request(:any, /evil|http:/)).not_to have_been_made
    end

    it "refuses to follow a redirect to a non-GitHub URL" do
      stub_redirect("/x", "https://evil.example.com/steal")

      expect { client.get("/x") }.to raise_error(described_class::Error, /evil\.example\.com/)
      expect(a_request(:any, /evil/)).not_to have_been_made
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

  describe "#post" do
    it "sends a JSON body" do
      stub =
        stub_request(:post, "https://api.github.com/repos/d/d/issues/1/comments").with(
          body: { body: "hi" }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        ).to_return(status: 201, body: "{}")
      client.post("/repos/d/d/issues/1/comments", { body: "hi" })
      expect(stub).to have_been_requested
    end
  end
end
