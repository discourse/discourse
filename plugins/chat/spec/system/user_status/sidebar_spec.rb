# frozen_string_literal: true

RSpec.describe "User status | sidebar" do
  fab!(:current_user, :user)
  fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }

  before do
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.enable_user_status = true
    chat_system_bootstrap
    current_user.set_status!("online", "heart")
    sign_in(current_user)
  end

  it "shows the current status, then updates and clears it without reloading" do
    visit("/")

    expect(find(".user-status-message .emoji")["alt"]).to eq("heart")
    expect(find(".user-status-message .emoji")["src"]).to include("heart")

    current_user.set_status!("offline", "tooth")

    expect(page).to have_css('.user-status-message img.emoji[alt="tooth"]')

    current_user.clear_status!

    expect(page).to have_no_css(".user-status-message")
  end
end
