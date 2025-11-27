# frozen_string_literal: true

RSpec.describe ThemeSiteSetting do
  fab!(:theme_1, :theme)
  fab!(:theme_2, :theme)
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

  describe "creating upload references for type objects settings with upload fields" do
    fab!(:upload)
    fab!(:upload2, :upload)

    it "creates upload references for settings with upload fields" do
      theme_site_setting =
        ThemeSiteSetting.create!(
          theme: theme_1,
          name: "test_objects_with_uploads",
          data_type: SiteSettings::TypeSupervisor.types[:objects],
          value:
            JSON.generate(
              [
                { "name" => "object1", "upload_id" => upload.id },
                { "name" => "object2", "upload_id" => upload2.id },
              ],
            ),
        )

      upload_references = UploadReference.where(target: theme_site_setting)
      expect(upload_references.pluck(:upload_id)).to contain_exactly(upload.id, upload2.id)
    end

    it "destroys upload references when the setting is destroyed" do
      theme_site_setting =
        ThemeSiteSetting.create!(
          theme: theme_1,
          name: "test_objects_with_uploads",
          data_type: SiteSettings::TypeSupervisor.types[:objects],
          value:
            JSON.generate(
              [
                { "name" => "object1", "upload_id" => upload.id },
                { "name" => "object2", "upload_id" => upload2.id },
              ],
            ),
        )

      expect { theme_site_setting.destroy! }.to change { UploadReference.count }.by(-2)
    end
  end
end
