# frozen_string_literal: true

RSpec.describe "Anonymous public chat channels" do
  fab!(:public_channel) { Fabricate(:category_channel, name: "general") }
  fab!(:private_channel, :private_category_channel)
  fab!(:existing_message) do
    Fabricate(
      :chat_message,
      chat_channel: public_channel,
      message: "Existing public channel update",
    )
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }
  let(:login_page) { PageObjects::Pages::Login.new }

  before do
    chat_system_bootstrap
    SiteSetting.chat_allowed_groups =
      "#{Group::AUTO_GROUPS[:everyone]}|#{Group::AUTO_GROUPS[:anonymous_users]}"
  end

  it "lets visitors read public channel activity without write or browse controls" do
    chat_page.visit_channels

    expect(chat_page).to have_public_channel(public_channel)
    expect(chat_page).to have_no_public_channel(private_channel)
    expect(chat_page).to have_no_browse_page_button

    chat_page.open_public_channel(public_channel)

    expect(channel_page.messages).to have_message(
      id: existing_message.id,
      text: "Existing public channel update",
    )
    expect(channel_page).to have_join_channel_button
    expect(channel_page).to have_no_composer
    expect(channel_page).to have_no_search_button
    expect(channel_page).to have_no_star_button
    expect(channel_page).to have_no_browse_all_link

    channel_page.join_channel

    expect(login_page).to be_open
  end

  it "streams public channel activity to the drawer and full page for visitors" do
    SiteSetting.navigation_menu = "sidebar"

    visit("/")
    chat_page.open_from_header
    expect(chat_drawer_page).to have_open_channels

    chat_drawer_page.open_channel(public_channel)
    expect(chat_drawer_page).to have_open_channel(public_channel)

    live_message =
      Fabricate(
        :chat_message,
        chat_channel: public_channel,
        message: "Live anonymous public channel update",
        use_service: true,
      )

    expect(chat_drawer_page.messages).to have_message(
      id: live_message.id,
      text: "Live anonymous public channel update",
    )

    chat_drawer_page.maximize

    expect(page).to have_current_path(public_channel.url)
    expect(channel_page.messages).to have_message(
      id: live_message.id,
      text: "Live anonymous public channel update",
    )
  end

  it "keeps visitors out of browse" do
    visit("/chat/browse/open")

    expect(page).to have_current_path("/chat/channels")
  end

  it "renders threaded public channels for visitors" do
    public_channel.update!(threading_enabled: true)

    chat_page.visit_channels

    expect(chat_page).to have_public_channel(public_channel)
  end
end
