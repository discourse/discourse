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

  xdescribe ".valid_value?" do
    let(:deprecated_test) { "#{Rails.root}/spec/fixtures/site_settings/deprecated_test.yml" }

    before { SiteSetting.load_settings(deprecated_test) }

    it "allows all trust levels as valid values" do
      expect(TrustLevelSetting.valid_value?(TrustLevel[0])).to eq(true)
      expect(TrustLevelSetting.valid_value?(TrustLevel[1])).to eq(true)
      expect(TrustLevelSetting.valid_value?(TrustLevel[2])).to eq(true)
      expect(TrustLevelSetting.valid_value?(TrustLevel[3])).to eq(true)
      expect(TrustLevelSetting.valid_value?(TrustLevel[4])).to eq(true)
      expect(TrustLevelSetting.valid_value?(20)).to eq(false)
    end

    it "does not allow 'admin' or 'staff' as valid values" do
      expect(TrustLevelSetting.valid_value?("admin")).to eq(false)
      expect(TrustLevelSetting.valid_value?("staff")).to eq(false)
    end

    it "does not allow setting 'admin' or 'staff' as valid values" do
      expect { SiteSetting.min_trust_level_to_allow_invite = "admin" }.to raise_error(
        Discourse::InvalidParameters,
      )
      expect { SiteSetting.min_trust_level_to_allow_invite = "staff" }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end
end
