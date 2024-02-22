# frozen_string_literal: true

RSpec.describe "User status | sidebar", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.enable_user_status = true
    chat_system_bootstrap
    current_user.set_status!("online", "heart")
    sign_in(current_user)
  end

  it "shows user status" do
    visit("/")

    expect(find(".user-status-message .emoji")["alt"]).to eq("heart")
    expect(find(".user-status-message .emoji")["src"]).to include("heart")
  end

  context "when changing status" do
    it "updates status" do
      visit("/")

      current_user.set_status!("offline", "tooth")

      expect(page).to have_css('.user-status-message img.emoji[alt="tooth"]')
    end
  end

  context "when removing status" do
    it "removes status" do
      visit("/")
      current_user.clear_status!

      expect(page).to have_no_css(".user-status-message")
    end
  end
end
