# frozen_string_literal: true

RSpec.describe ThemeSiteSettingResolver do
  fab!(:theme)

  subject(:resolver) { described_class.new(theme: theme) }

  describe "#resolved_theme_site_settings" do
    let(:themeable_setting) { :enable_welcome_banner }
    let(:default_value) { SiteSetting.defaults[themeable_setting] }

    it "returns themeable settings" do
      result = resolver.resolved_theme_site_settings
      expect(result.map { |s| s[:setting] }).to match_array(SiteSetting.themeable_site_settings)
    end

    it "returns settings in alphabetical order" do
      result = resolver.resolved_theme_site_settings
      expect(result.map { |r| r[:setting] }).to eq(SiteSetting.themeable_site_settings.sort)
    end

    it "includes metadata for each setting" do
      result = resolver.resolved_theme_site_settings.first
      expect(result).to include(
        setting: themeable_setting,
        default: default_value,
        description: I18n.t("site_settings.#{themeable_setting}"),
        type: "bool",
      )
    end

    context "when theme has not overridden any settings" do
      it "uses the default site setting value" do
        result = resolver.resolved_theme_site_settings.find { |s| s[:setting] == themeable_setting }
        expect(result[:value]).to eq(default_value)
        expect(result[:default]).to eq(default_value)
      end
    end

    context "when theme has overridden settings" do
      let(:overridden_value) { false }

      before do
        # Create a theme site setting override with a different value than default
        Fabricate(
          :theme_site_setting,
          theme: theme,
          name: themeable_setting.to_s,
          value: overridden_value,
          data_type: SiteSetting.types[:enum],
        )
      end

      it "uses the overridden value" do
        result = resolver.resolved_theme_site_settings.find { |s| s[:setting] == themeable_setting }
        expect(result[:value]).to eq(overridden_value)
        expect(result[:default]).to eq(default_value)
      end
    end

    context "with enum type settings" do
      let(:themeable_setting) { :search_experience }

      it "includes valid_values and translate_names" do
        result = resolver.resolved_theme_site_settings.find { |s| s[:setting] == themeable_setting }
        expect(result[:valid_values]).to be_an(Array)
        expect(result).to include(:translate_names)
      end
    end
  end
end
