# frozen_string_literal: true

RSpec.describe TopMenuValidator do
  describe "#valid_value?" do
    subject(:validator) { described_class.new }

    it "returns false for blank values" do
      expect(validator.valid_value?("")).to eq(false)
      expect(validator.error_message).to eq(I18n.t("site_settings.errors.must_include_latest"))

      expect(validator.valid_value?(nil)).to eq(false)
      expect(validator.error_message).to eq(I18n.t("site_settings.errors.must_include_latest"))
    end

    it "returns false when latest is missing" do
      expect(validator.valid_value?("categories|new")).to eq(false)
      expect(validator.error_message).to eq(I18n.t("site_settings.errors.must_include_latest"))
    end

    it "returns false when a choice is not in TopMenu.choices" do
      expect(validator.valid_value?("latest|random")).to eq(false)
    end

    it "returns true for a valid subset of choices that includes latest" do
      expect(validator.valid_value?("latest|new|hot|categories")).to eq(true)
    end

    it "returns false when unread is included and unified new is enabled" do
      SiteSetting.enable_unified_new = true

      expect(validator.valid_value?("latest|new|unread|hot|categories")).to eq(false)
      expect(validator.error_message).to eq(
        I18n.t("site_settings.errors.top_menu_unread_not_allowed_with_unified_new"),
      )
    end

    it "returns true when unread is included and unified new is disabled" do
      SiteSetting.enable_unified_new = false

      expect(validator.valid_value?("latest|new|unread|hot|categories")).to eq(true)
    end
  end
end
