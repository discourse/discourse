# frozen_string_literal: true

RSpec.describe "User chat preferences", type: :system, js: true do
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
end
