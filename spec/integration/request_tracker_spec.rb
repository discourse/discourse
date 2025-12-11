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

  context "when web request logging is enabled" do
    before { SiteSetting.enable_web_request_logging = true }

    it "logs web requests for API requests" do
      expect {
        get "/u/#{api_key.user.username}.json", headers: { HTTP_API_KEY: api_key.key }
      }.to change { WebRequestLog.count }.by(1)

      expect(response.status).to eq(200)

      log = WebRequestLog.order(:created_at).last
      expect(log.is_api).to eq(true)
      expect(log.http_status).to eq(200)
      expect(log.path).to eq("/u/#{api_key.user.username}.json")
      expect(log.route).to eq("users#show")
      expect(log.ip_address).to be_present
    end

    it "logs web requests for user API requests" do
      expect {
        get "/session/current.json", headers: { HTTP_USER_API_KEY: user_api_key.key }
      }.to change { WebRequestLog.count }.by(1)

      expect(response.status).to eq(200)

      log = WebRequestLog.order(:created_at).last
      expect(log.is_user_api).to eq(true)
      expect(log.route).to eq("session#current")
    end

    it "logs web requests for HTML page requests" do
      user = Fabricate(:user)

      expect {
        get "/u/#{user.username}",
            headers: {
              "HTTP_USER_AGENT" =>
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            }
      }.to change { WebRequestLog.count }.by(1)

      expect(response.status).to eq(200)

      log = WebRequestLog.order(:created_at).last
      expect(log.is_api).to eq(false)
      expect(log.is_crawler).to eq(false)
      expect(log.path).to eq("/u/#{user.username}")
      expect(log.route).to eq("users#show")
    end

    it "logs crawler requests" do
      user = Fabricate(:user)

      expect {
        get "/u/#{user.username}",
            headers: {
              "HTTP_USER_AGENT" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
            }
      }.to change { WebRequestLog.count }.by(1)

      log = WebRequestLog.order(:created_at).last
      expect(log.is_crawler).to eq(true)
      expect(log.user_agent).to include("Googlebot")
    end

    it "captures referrer when present" do
      user = Fabricate(:user)

      get "/u/#{user.username}", headers: { "HTTP_REFERER" => "https://google.com/search?q=test" }

      log = WebRequestLog.order(:created_at).last
      expect(log.referrer).to eq("https://google.com/search?q=test")
    end

    it "does not log when setting is disabled" do
      SiteSetting.enable_web_request_logging = false

      expect {
        get "/u/#{api_key.user.username}.json", headers: { HTTP_API_KEY: api_key.key }
      }.not_to change { WebRequestLog.count }
    end
  end
end
