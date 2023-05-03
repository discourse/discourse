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
    ApplicationRequest.delete_all
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
end
