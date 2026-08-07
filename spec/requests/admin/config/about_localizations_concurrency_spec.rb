# frozen_string_literal: true

RSpec.describe Admin::Config::AboutController do
  self.use_transactional_tests = false

  fab!(:admin)

  before do
    sign_in(admin)
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "ja|pt_BR"
  end

  after do
    UserHistory.where(acting_user_id: admin.id).delete_all
    admin.destroy!
  end

  it "returns a successful response when a concurrent first create leaves a stale lookup" do
    put "/admin/config/about/localizations.json",
        params: {
          locale: "ja",
          general_settings: {
            name: "Original title",
          },
        }

    expect(response.status).to eq(200)

    stale_localization = SiteSettingLocalization.new(setting_name: "title", locale: "ja")
    SiteSettingLocalization.stubs(:find_by).with(setting_name: "title", locale: "ja").returns(nil)
    SiteSettingLocalization
      .stubs(:find_or_initialize_by)
      .with(setting_name: "title", locale: "ja")
      .returns(stale_localization)
    SiteSettingLocalization.any_instance.stubs(:valid?).returns(true)

    put "/admin/config/about/localizations.json",
        params: {
          locale: "ja",
          general_settings: {
            name: "Updated title",
          },
        }

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("localizations", "title", "value")).to eq("Updated title")
    expect(SiteSettingLocalization.where(setting_name: "title", locale: "ja").count).to eq(1)
  end
end
