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

  describe ".scope_mappings" do
    it "does not define a granular scope for about requests" do
      expect(described_class.scope_mappings).not_to have_key(:about)
    end
  end
end
