# frozen_string_literal: true

RSpec.describe "Drawer - direct messages", type: :system do
  fab!(:current_user, :user)

  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  it "shows a button for chat search" do
    drawer_page.visit_direct_messages

    expect(page).to have_selector(".chat-channel-search-btn")
  end
end
