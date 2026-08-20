# frozen_string_literal: true

RSpec.describe Admin::Config::AboutController do
  fab!(:admin)
  fab!(:another_admin, :admin)

  before do
    sign_in(admin)
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "ja|pt_BR"
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

    SiteSettingLocalization.stubs(:find_by).with(setting_name: "title", locale: "ja").returns(nil)
    sign_in(another_admin)

    put "/admin/config/about/localizations.json",
        params: {
          locale: "ja",
          general_settings: {
            name: "Updated title",
          },
        }

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("localizations", "title", "value")).to eq("Updated title")

    localization = SiteSettingLocalization.where(setting_name: "title", locale: "ja").sole
    expect(localization).to have_attributes(
      value: "Updated title",
      localizer_user_id: another_admin.id,
    )
  end
end
