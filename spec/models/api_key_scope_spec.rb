# frozen_string_literal: true

RSpec.describe ApiKeyScope do
  describe ".find_urls" do
    it "should return the right urls" do
      expect(ApiKeyScope.find_urls(actions: ["posts#create"], methods: [])).to contain_exactly(
        "/posts (POST)",
      )
    end

    it "should return logster urls" do
      expect(ApiKeyScope.find_urls(actions: [Logster::Web], methods: [])).to contain_exactly(
        "/logs/messages.json (POST)",
        "/logs/show/:id.json (GET)",
      )
    end
  end
end
