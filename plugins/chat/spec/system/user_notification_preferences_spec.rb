# frozen_string_literal: true

RSpec.describe "User notification preferences | Chat notifications" do
  fab!(:current_user, :user)

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  def visit_notifications
    page.visit("/my/preferences/notifications")
  end

  def combo(selector)
    PageObjects::Components::SelectKit.new(selector)
  end

  def save
    find(".save-changes").click
    expect(page).to have_css(".saved")
  end

  context "when chat is disabled site-wide" do
    before { SiteSetting.chat_enabled = false }

    it "does not render the chat notifications section" do
      visit_notifications

      expect(page).to have_no_css(".control-group.chat-notifications")
    end
  end

  context "when the user has disabled chat" do
    before { current_user.user_option.update!(chat_enabled: false) }

    it "does not render the chat notifications section" do
      visit_notifications

      expect(page).to have_no_css(".control-group.chat-notifications")
    end
  end

  it "renders the chat notifications section" do
    visit_notifications

    expect(page).to have_css(".control-group.chat-notifications")
  end

  it "can change and persist the chat notification settings" do
    visit_notifications

    combo(".chat-header-indicator-preference").expand
    combo(".chat-header-indicator-preference").select_row_by_value("dm_and_mentions")

    combo(".chat-sound").expand
    combo(".chat-sound").select_row_by_value("retro")

    save
    visit_notifications

    expect(combo(".chat-header-indicator-preference").value).to eq("dm_and_mentions")
    expect(combo(".chat-sound").value).to eq("retro")
  end
end
