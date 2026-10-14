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

    it "supports optional credentials and vision for both providers" do
      described_class::PROVIDERS.each do |provider|
        model = Fabricate(:decision_model, provider:, ai_secret: nil, vision_enabled: true)
        expect(model.reload.vision_enabled).to eq(true)
        expect(model.api_key).to be_nil
      end
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

  describe "#endpoint_url" do
    it "resolves SRV endpoints while preserving the path" do
      model = Fabricate.build(:decision_model, url: "srv://_decisions._tcp.example.com/v1/decide")
      DiscourseAi::Utils::DnsSrv
        .stubs(:lookup)
        .with("_decisions._tcp.example.com")
        .returns(Resolv::DNS::Resource::IN::SRV.new(0, 0, 8443, "engine.example.com"))
      expect(model.endpoint_url).to eq("https://engine.example.com:8443/v1/decide")
    end

    it "raises a non-retryable error when discovery fails" do
      model = Fabricate.build(:decision_model, url: "srv://missing.example.com/path")
      DiscourseAi::Utils::DnsSrv.stubs(:lookup).returns(nil)
      expect { model.endpoint_url }.to raise_error(DiscourseAi::Decisions::RequestFailed) { |error|
        expect(error).not_to be_retryable
      }

      DiscourseAi::Utils::DnsSrv.stubs(:lookup).raises(Resolv::ResolvTimeout)
      expect { model.endpoint_url }.to raise_error(
        DiscourseAi::Decisions::RequestFailed,
        /SRV lookup/,
      )
    end
  end
end
