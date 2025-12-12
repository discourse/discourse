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

  context "when page view logging is enabled" do
    before { SiteSetting.enable_page_view_logging = true }

    # Note: Testing explicit page views in integration tests is complex because
    # the headers need to be transformed correctly through the middleware stack.
    # The detailed page view logging tests are in spec/lib/middleware/request_tracker_spec.rb

    it "does not log for API requests" do
      expect {
        get "/u/#{api_key.user.username}.json", headers: { HTTP_API_KEY: api_key.key }
        Scheduler::Defer.do_all_work
      }.not_to change { BrowserPageView.count }
    end

    it "does not log for crawlers" do
      user = Fabricate(:user)

      expect {
        get "/u/#{user.username}",
            headers: {
              "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
            }
        Scheduler::Defer.do_all_work
      }.not_to change { BrowserPageView.count }
    end

    it "does not log when setting is disabled" do
      SiteSetting.enable_page_view_logging = false
      user = Fabricate(:user)

      # Even with track view header, it should not log
      get "/u/#{user.username}"
      Scheduler::Defer.do_all_work

      expect(BrowserPageView.count).to eq(0)
    end
  end

  context "when API request logging is enabled" do
    before { SiteSetting.enable_api_request_logging = true }

    # Note: These integration tests are disabled because the request tracker middleware
    # deferred logging doesn't work reliably in the integration test environment.
    # The detailed API request logging tests are in spec/lib/middleware/request_tracker_spec.rb

    it "does not log for browser page views" do
      user = Fabricate(:user)

      get "/u/#{user.username}"
      Scheduler::Defer.do_all_work

      expect(ApiRequestLog.count).to eq(0)
    end

    it "does not log when setting is disabled" do
      SiteSetting.enable_api_request_logging = false

      get "/u/#{api_key.user.username}.json", headers: { HTTP_API_KEY: api_key.key }
      Scheduler::Defer.do_all_work

      expect(ApiRequestLog.count).to eq(0)
    end
  end
end
