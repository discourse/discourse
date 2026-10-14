# frozen_string_literal: true

RSpec.describe DecisionModel do
  before { enable_current_plugin }

  describe "validations" do
    it "requires a supported provider, URL and an existing credential when selected" do
      [
        nil,
        "ftp://example.com",
        "garbage https://example.com",
        "https:///missing-host",
        "srv://_decisions._tcp.example.com:8443/path",
      ].each do |url|
        model = Fabricate.build(:decision_model, url:)
        expect(model).not_to be_valid
        expect(model.errors[:url]).to be_present
      end
      expect(Fabricate.build(:decision_model, provider: "unknown")).not_to be_valid
      expect(
        DecisionModel.new(
          display_name: "Test",
          name: "test",
          provider: "system_one",
          url: "https://example.com",
          ai_secret_id: -1,
        ),
      ).not_to be_valid
      expect(
        Fabricate.build(
          :decision_model,
          ai_secret: nil,
          url: "srv://_decisions._tcp.example.com/path",
        ),
      ).to be_valid
    end
  end

  describe ".presets" do
    it "provides immutable preset metadata" do
      expect(described_class.presets.map { |preset| preset[:name] }).to eq(
        %w[jev-latest vllm-sr/d3 clef clef-flash gpt-6-luna],
      )
      expect(described_class.presets).to be_frozen
      expect(described_class.presets).to all(be_frozen)
    end
  end
end
