# frozen_string_literal: true

RSpec.describe ThemeSiteSetting do
  fab!(:theme_1) { Fabricate(:theme) }
  fab!(:theme_2) { Fabricate(:theme) }
  fab!(:theme_site_setting_1) do
    Fabricate(
      :theme_site_setting_with_service,
      theme: theme_1,
      name: "enable_welcome_banner",
      value: false,
    )
  end
  fab!(:theme_site_setting_2) do
    Fabricate(
      :theme_site_setting_with_service,
      theme: theme_1,
      name: "search_experience",
      value: "search_field",
    )
  end

  describe ".generate_theme_map" do
    it "returns a map of theme ids mapped to theme site settings, using site setting defaults if the setting records do not exist" do
      expect(ThemeSiteSetting.generate_theme_map).to include(
        {
          theme_1.id => {
            enable_welcome_banner: false,
            search_experience: "search_field",
          },
          theme_2.id => {
            enable_welcome_banner: true,
            search_experience: "search_icon",
          },
        },
      )
    end

    context "when skipping redis" do
      before { GlobalSetting.skip_redis = true }
      after { GlobalSetting.skip_redis = false }

      it "returns {}" do
        expect(ThemeSiteSetting.generate_theme_map).to eq({})
      end
    end

    context "when skipping db" do
      before { GlobalSetting.skip_db = true }
      after { GlobalSetting.skip_db = false }

      it "returns {}" do
        expect(ThemeSiteSetting.generate_theme_map).to eq({})
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

      it "returns {}" do
        expect(ThemeSiteSetting.generate_theme_map).to eq({})
      end
    end
  end
end
