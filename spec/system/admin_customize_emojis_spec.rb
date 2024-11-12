#frozen_string_literal: true

describe "Admin Customize Emoji Page", type: :system do
  fab!(:current_user) { Fabricate(:admin) }

  let(:emojis_page) { PageObjects::Pages::AdminEmojis.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  before do
    Fabricate(:custom_emoji)

    sign_in(current_user)
  end

  it "shows a list of custom emojis" do
    emojis_page.visit_page
    expect(emojis_page).to have_emoji_listed("joffrey_facepalm")
  end

  it "can delete a custom emoji" do
    emojis_page.visit_page
    emojis_page.delete_emoji("joffrey_facepalm")
    dialog.click_yes
    expect(emojis_page).to have_no_emoji_listed("joffrey_facepalm")
  end

  it "can see emoji site settings" do
    emojis_page.visit_page
    emojis_page.click_tab("settings")
    expect(settings_page).to have_setting("enable_emoji")
  end
end
