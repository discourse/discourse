# frozen_string_literal: true

describe "Admin chat homepage channel setting" do
  fab!(:admin)
  fab!(:channel_1) { Fabricate(:category_channel, name: "General") }

  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  let(:changes_banner) { PageObjects::Components::AdminChangesBanner.new }

  before do
    chat_system_bootstrap
    sign_in(admin)
  end

  it "reveals the channel picker only once the homepage is set to chat" do
    settings_page.visit("default_homepage")

    expect(page).to have_no_css("[data-setting='chat_homepage_channel']")

    settings_page.select_enum_value("default_homepage", "chat")
    settings_page.save_setting("default_homepage")

    expect(settings_page.find_setting("default_homepage")).to have_css(
      "[data-setting='chat_homepage_channel']",
    )

    settings_page.select_enum_value("chat_homepage_channel", channel_1.id.to_s)
    changes_banner.click_save
    page.refresh

    expect(settings_page.enum_setting("chat_homepage_channel").value).to eq(channel_1.id.to_s)
  end
end
