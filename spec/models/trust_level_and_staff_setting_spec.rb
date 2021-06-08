# frozen_string_literal: true

require 'rails_helper'

describe TrustLevelAndStaffSetting do
  describe ".values" do
    after do
      I18n.reload!
    end

    it "returns translated names" do
      TranslationOverride.upsert!(I18n.locale, "js.trust_levels.names.newuser", "New Member")
      TranslationOverride.upsert!(I18n.locale, "trust_levels.admin", "Hero")

      values = TrustLevelAndStaffSetting.values

      value = values.find { |v| v[:value] == 0 }
      expect(value).to be_present
      expect(value[:name]).to eq(I18n.t("js.trust_levels.detailed_name", level: 0, name: "New Member"))

      value = values.find { |v| v[:value] == "admin" }
      expect(value).to be_present
      expect(value[:name]).to eq("Hero")

      value = values.find { |v| v[:value] == "staff" }
      expect(value).to be_present
      expect(value[:name]).to eq(I18n.t("trust_levels.staff"))
    end
  end
end
