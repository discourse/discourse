# frozen_string_literal: true

RSpec.describe "request tracker" do
  let(:api_key) do
    Fabricate(
      :api_key,
      user: Fabricate.build(:user),
      api_key_scopes: [ApiKeyScope.new(resource: "users", action: "show")],
    )
  end

  let(:user_api_key) do
    Fabricate(:user_api_key, scopes: [Fabricate.build(:user_api_key_scope, name: "session_info")])
  end

  before do
    CachedCounting.reset
    CachedCounting.enable
    ApplicationRequest.enable
  end

  after do
    ApplicationRequest.disable
    CachedCounting.reset
    CachedCounting.disable
  end

  context "when using an api key" do
    it "is counted as an API request" do
      get "/u/#{api_key.user.username}.json", headers: { HTTP_API_KEY: api_key.key }
      expect(response.status).to eq(200)

      CachedCounting.flush
      expect(ApplicationRequest.http_total.first.count).to eq(1)
      expect(ApplicationRequest.http_2xx.first.count).to eq(1)
      expect(ApplicationRequest.api.first.count).to eq(1)
    end
  end

  context "when using an user api key" do
    it "is counted as a user API request" do
      get "/session/current.json", headers: { HTTP_USER_API_KEY: user_api_key.key }
      expect(response.status).to eq(200)

      CachedCounting.flush
      expect(ApplicationRequest.http_total.first.count).to eq(1)
      expect(ApplicationRequest.http_2xx.first.count).to eq(1)
      expect(ApplicationRequest.user_api.first.count).to eq(1)
    end
  end

  context "when browser page view logging is enabled" do
    before { SiteSetting.enable_browser_page_view_logging = true }

    it "logs browser page views for API requests" do
      expect {
        get "/u/#{api_key.user.username}.json", headers: { HTTP_API_KEY: api_key.key }
      }.to change { BrowserPageView.count }.by(1)

      expect(response.status).to eq(200)

      view = BrowserPageView.order(:created_at).last
      expect(view.is_api).to eq(true)
      expect(view.http_status).to eq(200)
      expect(view.url).to eq("/u/#{api_key.user.username}.json")
      expect(view.route).to eq("users#show")
      expect(view.ip_address).to be_present
    end

    it "logs browser page views for user API requests" do
      expect {
        get "/session/current.json", headers: { HTTP_USER_API_KEY: user_api_key.key }
      }.to change { BrowserPageView.count }.by(1)

      expect(response.status).to eq(200)

      view = BrowserPageView.order(:created_at).last
      expect(view.is_user_api).to eq(true)
      expect(view.route).to eq("session#current")
    end

    it "logs browser page views for HTML page requests" do
      user = Fabricate(:user)

      expect {
        get "/u/#{user.username}",
            headers: {
              "HTTP_USER_AGENT" =>
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            }
      }.to change { BrowserPageView.count }.by(1)

      expect(response.status).to eq(200)

      view = BrowserPageView.order(:created_at).last
      expect(view.is_api).to eq(false)
      expect(view.is_crawler).to eq(false)
      expect(view.url).to eq("/u/#{user.username}")
      expect(view.route).to eq("users#show")
    end

    it "logs crawler page views" do
      user = Fabricate(:user)

      expect {
        get "/u/#{user.username}",
            headers: {
              "HTTP_USER_AGENT" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
            }
      }.to change { BrowserPageView.count }.by(1)

      view = BrowserPageView.order(:created_at).last
      expect(view.is_crawler).to eq(true)
      expect(view.user_agent).to include("Googlebot")
    end

    it "captures referrer when present" do
      user = Fabricate(:user)

      get "/u/#{user.username}", headers: { "HTTP_REFERER" => "https://google.com/search?q=test" }

      view = BrowserPageView.order(:created_at).last
      expect(view.referrer).to eq("https://google.com/search?q=test")
    end

    it "does not log when setting is disabled" do
      SiteSetting.enable_browser_page_view_logging = false

      expect {
        get "/u/#{api_key.user.username}.json", headers: { HTTP_API_KEY: api_key.key }
      }.not_to change { BrowserPageView.count }
    end
  end
end
