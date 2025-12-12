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
    drawer_page.open_chat_search

    expect(drawer_page).to have_open_chat_search

    drawer_page.back

    expect(drawer_page).to have_open_direct_messages
  end
end
