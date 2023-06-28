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
    click_link "chat-message-"

    sleep 1
    DOWNLOAD_PATH = Rails.root.join("tmp/downloads").to_s
    full_path = DOWNLOAD_PATH + "/partners-#{Date.today}.csv"
    assert File.exist?(full_path)
    headers = CSV.open(full_path, "r") { |csv| csv.first.to_s }
    assert_equal(
      headers,
      "[\"id\", \"name\", \"partner_type_id\", \"parent_id\", \"phone\", \"website\"]",
      "Header does not match",
    )
  end

  it "exports user list" do
    visit("admin/users/list/active")
    expect(page).to have_current_path("/latest")
  end
end
