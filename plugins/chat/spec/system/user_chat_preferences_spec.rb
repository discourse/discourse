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

    it "doesn’t show the tab" do
      visit("/my/preferences")

      expect(page).to have_no_css(".user-nav__preferences-chat", visible: :all)
    end

    it "shows a not found page" do
      visit("/my/preferences/chat")

      expect(page).to have_content(I18n.t("page_not_found.title"))
    end
  end

  it "can select chat sound" do
    visit("/my/preferences")
    find(".user-nav__preferences-chat", visible: :all).click
    select_kit = PageObjects::Components::SelectKit.new("#user_chat_sounds")
    select_kit.expand
    select_kit.select_row_by_value("bell")
    find(".save-changes").click

    expect(select_kit).to have_selected_value("bell")
  end

  it "can select header_indicator_preference" do
    visit("/my/preferences")
    find(".user-nav__preferences-chat", visible: :all).click
    select_kit = PageObjects::Components::SelectKit.new("#user_chat_header_indicator_preference")
    select_kit.expand
    select_kit.select_row_by_value("dm_and_mentions")
    find(".save-changes").click

    expect(select_kit).to have_selected_value("dm_and_mentions")
  end

  it "can select separate sidebar mode" do
    visit("/my/preferences")
    find(".user-nav__preferences-chat", visible: :all).click
    select_kit = PageObjects::Components::SelectKit.new("#user_chat_separate_sidebar_mode")
    select_kit.expand
    select_kit.select_row_by_value("fullscreen")
    find(".save-changes").click

    expect(select_kit).to have_selected_value("fullscreen")
  end

  context "as an admin on another user's preferences" do
    fab!(:current_user) { Fabricate(:admin) }
    fab!(:user_1) { Fabricate(:user) }

    before { sign_in(current_user) }

    it "allows to change settings" do
      visit("/u/#{user_1.username}/preferences")
      find(".user-nav__preferences-chat", visible: :all).click

      expect(page).to have_current_path("/u/#{user_1.username}/preferences/chat")
    end
  end
end
