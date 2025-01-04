# frozen_string_literal: true

RSpec.describe TrustLevelSetting do
  describe ".values" do
    after { I18n.reload! }

    it "returns translated names" do
      TranslationOverride.upsert!(I18n.locale, "js.trust_levels.names.newuser", "New Member")

      value = TrustLevelSetting.values.first
      expect(value[:name]).to eq(
        I18n.t("js.trust_levels.detailed_name", level: 0, name: "New Member"),
      )
      expect(value[:value]).to eq(0)
    end
  end
end
