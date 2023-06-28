# frozen_string_literal: true

RSpec.describe "Chat exports", type: :system do
  fab!(:current_user) { Fabricate(:admin) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:browse_page) { PageObjects::Pages::ChatBrowse.new }

  before do
    Jobs.run_immediately!
    sign_in(current_user)
    chat_system_bootstrap
  end

  it "exports chat messages" do
    visit "/admin/plugins/chat"
    click_button "Create export"
    click_button "OK"
    visit "/u/#{current_user.username}/messages"
    click_link "[Chat Message] Data export complete"
    expect(page).to have_current_path("/latest")
  end

  it "exports user list" do
    visit("admin/users/list/active")
    expect(page).to have_current_path("/latest")
  end
end
