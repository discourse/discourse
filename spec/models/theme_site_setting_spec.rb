# frozen_string_literal: true

RSpec.describe ThemeSiteSetting do
  fab!(:theme)
  fab!(:theme_site_setting_1) do
    Fabricate(:theme_site_setting, theme: theme, name: "enable_welcome_banner", value: false)
  end
  fab!(:theme_site_setting_2) do
    Fabricate(:theme_site_setting, theme: theme, name: "search_experience", value: "search_field")
  end

  describe "#all" do
    it "returns all theme site settings" do
      expect(ThemeSiteSetting.all).to match_array([theme_site_setting_1, theme_site_setting_2])
    end

    context "when skipping redis" do
      before { GlobalSetting.skip_redis = true }

      it "returns []" do
        GlobalSetting.skip_redis = true
        expect(ThemeSiteSetting.all).to eq([])
      end
    end

    context "when skipping db" do
      before { GlobalSetting.skip_db = true }

      it "returns []" do
        GlobalSetting.skip_db = true
        expect(ThemeSiteSetting.all).to eq([])
      end
    end

    context "when the table doesn't exist yet, in case of migrations" do
      before do
        ActiveRecord::Base
          .connection
          .stubs(:table_exists?)
          .with(ThemeSiteSetting.table_name)
          .returns(false)
      end

      it "returns []" do
        expect(ThemeSiteSetting.all).to eq([])
      end
    end
  end
end
