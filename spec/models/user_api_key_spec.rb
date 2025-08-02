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
end
