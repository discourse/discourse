# frozen_string_literal: true

RSpec.describe "Drawer - index", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  it "can leave a direct message" do
    channel = Fabricate(:direct_message_channel, users: [current_user])
    row = PageObjects::Components::Chat::ChannelRow.new(channel.id)

    drawer_page.visit_index
    drawer_page.click_direct_messages

    expect(row).to exist

    row.leave

    expect(row).to be_non_existent
  end

  it "can leave a group message" do
    channel =
      Fabricate(
        :direct_message_channel,
        group: true,
        users: [current_user, Fabricate(:user), Fabricate(:user)],
      )
    row = PageObjects::Components::Chat::ChannelRow.new(channel.id)

    drawer_page.visit_index
    drawer_page.click_direct_messages

    expect(row).to exist

    row.leave

    expect(row).to be_non_existent
  end

  it "can open browse" do
    channel = Fabricate(:chat_channel)

    drawer_page.visit_index
    drawer_page.channels_index.open_browse

    expect(drawer_page.browse).to have_channel(name: channel.name)
  end

  it "shows empty state when no dms" do
    drawer_page.visit_index
    drawer_page.click_direct_messages
    expect(page).to have_css("#c-footer-direct-messages.--active")
    expect(page).to have_selector(".channel-list-empty-message")
  end
end
