# frozen_string_literal: true

RSpec.describe "Chat exports", type: :system do
  fab!(:current_user) { Fabricate(:admin) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:browse_page) { PageObjects::Pages::ChatBrowse.new }

  before do
    sign_in(current_user)
    chat_system_bootstrap
  end

  it "exports chat messages" do
    Jobs.run_immediately!
    visit("/admin/plugins/chat")
    expect(page).to have_current_path("/latest")
  end

  it "exports user list" do
    Jobs.run_immediately!
    visit("admin/users/list/active")
    expect(page).to have_current_path("/latest")
  end
end
