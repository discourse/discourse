# frozen_string_literal: true

RSpec.describe "User chat preferences", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when chat disabled" do
    before do
      SiteSetting.chat_enabled = false
      sign_in(current_user)
    end

    it "shows a not found page" do
      visit("/u/#{current_user.username}/preferences/chat")

      expect(page).to have_content(I18n.t("page_not_found.title"))
    end
  end

  it "can select chat sound" do
    visit("/u/#{current_user.username}/preferences/chat")
    find("#user_chat_sounds .select-kit-header[data-value]").click
    find("[data-value='bell']").click
    find(".save-changes").click

    expect(page).to have_css("#user_chat_sounds .select-kit-header[data-value='bell']")
  end

  it "can select header_indicator_preference" do
    visit("/u/#{current_user.username}/preferences/chat")
    find("#user_chat_header_indicator_preference .select-kit-header[data-value]").click
    find("[data-value='dm_and_mentions']").click
    find(".save-changes").click

    expect(page).to have_css(
      "#user_chat_header_indicator_preference .select-kit-header[data-value='dm_and_mentions']",
    )
  end

  context "as an admin on another user's preferences" do
    fab!(:current_user) { Fabricate(:admin) }
    fab!(:user_1) { Fabricate(:user) }

    before { sign_in(current_user) }

    it "allows to change settings" do
      visit("/u/#{user_1.username}/preferences")

      find(".user-nav__preferences-chat").click

      expect(page).to have_current_path("/u/#{user_1.username}/preferences/chat")
    end
  end
end
