# frozen_string_literal: true

RSpec.describe DiscourseId do
  describe ".provider_url" do
    it "returns the default URL when setting is blank" do
      SiteSetting.discourse_id_provider_url = ""
      expect(described_class.provider_url).to eq("https://id.discourse.com")
    end

    it "returns the configured URL when setting is present" do
      SiteSetting.discourse_id_provider_url = "https://custom.example.com"
      expect(described_class.provider_url).to eq("https://custom.example.com")
    end
  end
end
