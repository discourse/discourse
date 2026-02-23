# frozen_string_literal: true

RSpec.describe "Plugin admin interface compatibility", type: :system do
  fab!(:current_user, :admin)

  before do
    sign_in(current_user)
    SiteSetting.data_explorer_enabled = true
    SiteSetting.discourse_automation_enabled = true
    SiteSetting.chat_enabled = true
    SiteSetting.discourse_ai_enabled = true
  end

  it "plugin admin interfaces do not bleed between plugins" do
    visit("/admin/plugins/discourse-ai")
    within(".admin-plugin-config-area") do
      expect(page).to have_css(".ai-features")
      expect(page).to have_no_css(".discourse-data-explorer-query-list")
      expect(page).to have_no_css(".discourse-automations-table")
      expect(page).to have_no_css(".discourse-chat-incoming-webhooks")
    end

    visit("/admin/plugins/discourse-data-explorer")
    within(".admin-plugin-config-area") do
      expect(page).to have_css(".discourse-data-explorer-query-list")
      expect(page).to have_no_css(".ai-features")
      expect(page).to have_no_css(".discourse-automations-table")
      expect(page).to have_no_css(".discourse-chat-incoming-webhooks")
    end

    visit("/admin/plugins/automation")
    within(".admin-plugin-config-area") do
      expect(page).to have_css(".discourse-automations-table")
      expect(page).to have_no_css(".ai-features")
      expect(page).to have_no_css(".discourse-data-explorer-query-list")
      expect(page).to have_no_css(".discourse-chat-incoming-webhooks")
    end

    visit("/admin/plugins/chat")
    within(".admin-plugin-config-area") do
      expect(page).to have_css(".discourse-chat-incoming-webhooks")
      expect(page).to have_no_css(".ai-features")
      expect(page).to have_no_css(".discourse-data-explorer-query-list")
      expect(page).to have_no_css(".discourse-automations-table")
    end
  end
end
