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

  describe "custom headers" do
    it "persists header rows, accepts boundary lengths and allows clearing them" do
      headers = [
        { "name" => "X-Token", "value" => "sensitive token" },
        { "name" => "X" * 128, "value" => "x" * 4000 },
        { "name" => "X-Empty", "value" => "" },
        { "name" => "X-!#$%&'*+-.^_`|~", "value" => " !~" },
      ]
      model = Fabricate(:decision_model, custom_headers: headers)
      expect(model.reload.custom_headers).to eq(headers)
      expect(Fabricate.build(:decision_model).custom_headers).to eq([])
      model.update!(custom_headers: [])
      expect(model.reload.custom_headers).to eq([])

      model.custom_headers = 20.times.map { |index| { name: "X-#{index}", value: "ok" } }
      expect(model).to be_valid
    end

    it "rejects invalid shapes, names, values, duplicate names and too many rows" do
      invalid_headers = [
        nil,
        {},
        "X-Token: secret",
        ["X-Token"],
        [{ name: "X-Token" }],
        [{ name: "X-Token", value: "ok", extra: "unexpected" }],
        [{ name: "", value: "ok" }],
        [{ name: "X" * 129, value: "ok" }],
        [{ name: "X Token", value: "ok" }],
        [{ name: "X:Token", value: "ok" }],
        [{ name: "X-Token\r\nInjected", value: "ok" }],
        [{ name: "X-☃", value: "ok" }],
        [{ name: 123, value: "ok" }],
        [{ name: "X-Token", value: nil }],
        [{ name: "X-Token", value: 123 }],
        [{ name: "X-Token", value: { secret: "bad" } }],
        [{ name: "X-Token", value: "x" * 4001 }],
        [{ name: "X-Token", value: "☃" }],
        [{ name: "X-Token", value: "first\r\nInjected: header" }],
        [{ name: "X-Token", value: "first\nsecond" }],
        [{ name: "X-Token", value: "first\tsecond" }],
        [{ name: "X-Token", value: "\u0000" }],
        [{ name: "X-Token", value: "\u007F" }],
        [{ name: "X-Token", value: "one" }, { name: "x-token", value: "two" }],
        21.times.map { |index| { name: "X-#{index}", value: "ok" } },
      ]
      %w[system_one typesafe].each do |provider|
        invalid_headers.each do |headers|
          model = Fabricate.build(:decision_model, provider:, custom_headers: headers)
          expect(model).not_to be_valid
          expect(model.errors[:custom_headers]).to be_present
          expect(model.custom_headers_for_request).to eq({})
        end
      end
    end

    it "rejects reserved headers regardless of case" do
      DecisionModel::RESERVED_CUSTOM_HEADERS.each do |name|
        model =
          Fabricate.build(:decision_model, custom_headers: [{ name: name.upcase, value: "x" }])
        expect(model).not_to be_valid
        expect(model.errors[:custom_headers]).to include(
          I18n.t("discourse_ai.decision_models.custom_headers.reserved_name"),
        )
      end
    end

    it "only permits nonempty custom headers for System One and TypeSafe" do
      model = Fabricate.build(:decision_model, custom_headers: [{ name: "X-Token", value: "x" }])
      %w[system_one typesafe].each do |provider|
        model.provider = provider
        expect(model).to be_valid
        expect(model.custom_headers_for_request).to eq("X-Token" => "x")
      end
      model.provider = "open_ai"
      expect(model).not_to be_valid
      expect(model.errors[:custom_headers]).to include(
        I18n.t("discourse_ai.decision_models.custom_headers.unsupported_provider"),
      )
      model.custom_headers = []
      expect(model).to be_valid
    end
  end

  describe ".presets" do
    it "provides a separate image-enabled Jev configuration" do
      preset = described_class.presets.find { |item| item[:preset_id] == "jev-latest-vision" }
      expect(preset).to include(
        name: "jev-latest",
        provider: "typesafe",
        url: "https://api.typesafe.ai/v1/systemone",
        vision_enabled: true,
        custom_headers: [{ name: "TypeSafe-Danger-Zone-Images", value: "true" }],
      )
      expect(preset[:custom_headers]).to be_frozen
      expect(preset[:custom_headers]).to all(be_frozen)
      expect(described_class.new(preset.except(:preset_id))).to be_valid
      text_preset = described_class.presets.find { |item| item[:preset_id] == "jev-latest" }
      expect(text_preset).to include(provider: "typesafe", vision_enabled: false)
      expect(described_class.new(text_preset.except(:preset_id))).to be_valid
      expect(
        described_class
          .presets
          .select { |item| item[:provider] == "system_one" }
          .map { |item| item[:preset_id] },
      ).to eq(%w[vllm-sr-d3 cloudflare-clef cloudflare-clef-flash])
    end

    it "provides immutable preset metadata" do
      expect(described_class.presets.map { |preset| preset[:preset_id] }).to eq(
        %w[
          jev-latest
          jev-latest-vision
          vllm-sr-d3
          cloudflare-clef
          cloudflare-clef-flash
          gpt-6-luna
        ],
      )
      expect(described_class.presets).to be_frozen
      expect(described_class.presets).to all(be_frozen)
    end
  end

  describe "#api_key" do
    it "reads seeded keys from the environment first, then the column, ignoring secrets" do
      seeded_model = Fabricate(:decision_model, id: -2, api_key: "column-key")
      expect(seeded_model.api_key).to eq("column-key")

      ENV["DISCOURSE_AI_SEEDED_DECISION_MODEL_API_KEY_2"] = "env-key"
      expect(seeded_model.api_key).to eq("env-key")
    ensure
      ENV.delete("DISCOURSE_AI_SEEDED_DECISION_MODEL_API_KEY_2")
    end

    it "uses the selected secret for admin-created models" do
      decision_model = Fabricate(:decision_model, api_key: "column-key")
      expect(decision_model.api_key).to eq(decision_model.ai_secret.secret)
    end
  end

  describe "#destroy" do
    it "removes the model's credit allocation, costs and usage" do
      allocation = Fabricate(:decision_model_credit_allocation, daily_used: 10)
      seeded_model = allocation.decision_model
      DecisionModelFeatureCreditCost.create!(decision_model: seeded_model, feature_name: "workflow")

      seeded_model.destroy!

      expect(DecisionModelCreditAllocation.exists?(allocation.id)).to eq(false)
      expect(DecisionModelFeatureCreditCost.exists?(decision_model_id: seeded_model.id)).to eq(
        false,
      )
      expect(DecisionModelCreditDailyUsage.exists?(decision_model_id: seeded_model.id)).to eq(false)
    end
  end
end
