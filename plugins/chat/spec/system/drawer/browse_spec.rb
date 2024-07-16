# frozen_string_literal: true

RSpec.describe "Drawer - Browse", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  fab!(:channel_1) { Fabricate(:chat_channel) }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  it "can change status" do
    drawer_page.visit_browse

    expect(drawer_page.browse).to have_channel(name: channel_1.name)

    drawer_page.browse.change_status("closed")

    expect(drawer_page.browse).to have_no_channel(name: channel_1.name)
  end
end
