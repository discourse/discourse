# frozen_string_literal: true

RSpec.describe GifsController do
  fab!(:user)

  before do
    SiteSetting.enable_gifs = true
    SiteSetting.klipy_api_key = "super secret/klipy+key"
  end

  describe "#search" do
    it "proxies Klipy requests with the configured API key without returning it" do
      sign_in(user)

      stub_request(:get, "https://api.klipy.com/v2/search").with(
        query:
          hash_including(
            "key" => SiteSetting.klipy_api_key,
            "q" => "hello",
            "country" => SiteSetting.klipy_country,
            "locale" => SiteSetting.klipy_locale,
            "contentfilter" => SiteSetting.klipy_content_filter,
            "media_filter" => SiteSetting.klipy_file_detail,
            "limit" => "24",
            "pos" => "0",
          ),
      ).to_return(status: 200, body: { results: [], next: "" }.to_json)

      get "/gifs/search.json", params: { q: "hello", pos: "0" }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("results" => [], "next" => "")
      expect(response.body).not_to include(SiteSetting.klipy_api_key)
    end

    it "requires a logged-in user" do
      get "/gifs/search.json", params: { q: "hello" }

      expect(response.status).to eq(403)
    end

    it "returns forbidden when no API key is configured" do
      SiteSetting.klipy_api_key = ""
      sign_in(user)

      get "/gifs/search.json", params: { q: "hello" }

      expect(response.status).to eq(403)
    end

    it "returns not found when GIF search is disabled" do
      SiteSetting.enable_gifs = false
      sign_in(user)

      get "/gifs/search.json", params: { q: "hello" }

      expect(response.status).to eq(404)
    end

    it "rejects queries longer than the maximum length" do
      sign_in(user)

      get "/gifs/search.json", params: { q: "a" * (GifsController::MAX_QUERY_LENGTH + 1) }

      expect(response.status).to eq(400)
    end

    it "returns bad gateway when Klipy cannot be reached" do
      sign_in(user)

      stub_request(:get, "https://api.klipy.com/v2/search").with(
        query: hash_including("q" => "hello"),
      ).to_timeout

      get "/gifs/search.json", params: { q: "hello" }

      expect(response.status).to eq(502)
    end

    it "redacts the API key from Klipy error responses" do
      sign_in(user)

      stub_request(:get, "https://api.klipy.com/v2/search").with(
        query: hash_including("key" => SiteSetting.klipy_api_key),
      ).to_return(status: 500, body: "upstream error #{CGI.escape(SiteSetting.klipy_api_key)}")

      get "/gifs/search.json", params: { q: "hello" }

      expect(response.status).to eq(500)
      expect(response.body).to include("[FILTERED]")
      expect(response.body).not_to include(SiteSetting.klipy_api_key)
      expect(response.body).not_to include(CGI.escape(SiteSetting.klipy_api_key))
    end

    context "when rate limiting is enabled" do
      before { RateLimiter.enable }

      it "returns 429 once the per-user limit is exceeded" do
        sign_in(user)

        stub_request(:get, "https://api.klipy.com/v2/search").with(
          query: hash_including("q" => "hello"),
        ).to_return(status: 200, body: { results: [], next: "" }.to_json)

        GifsController::MAX_REQUESTS_PER_10_SECONDS.times do
          get "/gifs/search.json", params: { q: "hello" }
          expect(response.status).to eq(200)
        end

        get "/gifs/search.json", params: { q: "hello" }
        expect(response.status).to eq(429)
      end
    end
  end

  describe "#categories" do
    it "proxies featured categories with the configured API key without returning it" do
      sign_in(user)

      stub_request(:get, "https://api.klipy.com/v2/categories").with(
        query:
          hash_including(
            "key" => SiteSetting.klipy_api_key,
            "type" => "featured",
            "country" => SiteSetting.klipy_country,
            "locale" => SiteSetting.klipy_locale,
            "contentfilter" => SiteSetting.klipy_content_filter,
          ),
      ).to_return(status: 200, body: { tags: [] }.to_json)

      get "/gifs/categories.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("tags" => [])
      expect(response.body).not_to include(SiteSetting.klipy_api_key)
    end

    it "requires a logged-in user" do
      get "/gifs/categories.json"

      expect(response.status).to eq(403)
    end
  end
end
