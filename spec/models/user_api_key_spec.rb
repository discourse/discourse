# frozen_string_literal: true

RSpec.describe UserApiKey do
  describe "#allow?" do
    def request_env(method, path, **path_parameters)
      ActionDispatch::TestRequest
        .create
        .tap do |request|
          request.request_method = method
          request.path = path
          request.path_parameters = path_parameters
        end
        .env
    end

    it "can look up permissions correctly" do
      key =
        UserApiKey.new(
          scopes: %w[message_bus notifications].map { |name| UserApiKeyScope.new(name: name) },
        )

      expect(key.allow?(request_env("GET", "/random"))).to eq(false)
      expect(key.allow?(request_env("POST", "/message-bus/1234/poll"))).to eq(true)

      expect(
        key.allow?(request_env("PUT", "/xyz", controller: "notifications", action: "mark_read")),
      ).to eq(true)

      expect(
        key.allow?(request_env("POST", "/xyz", controller: "user_api_keys", action: "revoke")),
      ).to eq(true)
    end

    it "can allow all correct scopes to write" do
      key = UserApiKey.new(scopes: ["write"].map { |name| UserApiKeyScope.new(name: name) })

      expect(key.allow?(request_env("GET", "/random"))).to eq(true)
      expect(key.allow?(request_env("PUT", "/random"))).to eq(true)
      expect(key.allow?(request_env("PATCH", "/random"))).to eq(true)
      expect(key.allow?(request_env("DELETE", "/random"))).to eq(true)
      expect(key.allow?(request_env("POST", "/random"))).to eq(true)
    end

    it "can allow blanket read" do
      key = UserApiKey.new(scopes: ["read"].map { |name| UserApiKeyScope.new(name: name) })

      expect(key.allow?(request_env("GET", "/random"))).to eq(true)
      expect(key.allow?(request_env("PUT", "/random"))).to eq(false)
    end
  end

  describe ".active" do
    it "includes unexpired keys and excludes expired and revoked keys" do
      freeze_time

      active_key = Fabricate(:readonly_user_api_key, expires_at: 1.hour.from_now)
      key_without_expiry = Fabricate(:readonly_user_api_key, expires_at: nil)
      expired_key = Fabricate(:readonly_user_api_key, expires_at: 1.minute.ago)
      revoked_key = Fabricate(:readonly_user_api_key, revoked_at: Time.zone.now)

      expect(described_class.active).to include(active_key, key_without_expiry)
      expect(described_class.active).not_to include(expired_key, revoked_key)
    end
  end

  describe "#expired?" do
    it "returns true only for keys past their expiry" do
      freeze_time

      expect(described_class.new(expires_at: 1.second.ago)).to be_expired
      expect(described_class.new(expires_at: 1.second.from_now)).not_to be_expired
      expect(described_class.new(expires_at: nil)).not_to be_expired
    end
  end

  describe ".push_clients_for" do
    it "excludes expired keys" do
      freeze_time
      SiteSetting.allow_user_api_key_scopes = "push"
      SiteSetting.allowed_user_api_push_urls = "https://push.example.com"
      user = Fabricate(:user)
      active_client = Fabricate(:user_api_key_client, client_id: "active-client")
      expired_client = Fabricate(:user_api_key_client, client_id: "expired-client")

      Fabricate(
        :user_api_key,
        user: user,
        client: active_client,
        push_url: "https://push.example.com",
        expires_at: 1.hour.from_now,
        scopes: [Fabricate.build(:user_api_key_scope, name: "push")],
      )
      Fabricate(
        :user_api_key,
        user: user,
        client: expired_client,
        push_url: "https://push.example.com",
        expires_at: 1.hour.ago,
        scopes: [Fabricate.build(:user_api_key_scope, name: "push")],
      )

      expect(described_class.push_clients_for(user)).to eq(
        [%w[active-client https://push.example.com]],
      )
    end
  end
end
