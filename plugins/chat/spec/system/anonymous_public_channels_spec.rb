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
  let(:thread_page) { PageObjects::Pages::ChatThread.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }
  let(:chat_sidebar_page) { PageObjects::Pages::ChatSidebar.new }
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

    channel_page.join_channel

    expect(login_page).to be_open
  end

  it "lets visitors open public chat channels from the sidebar drawer" do
    SiteSetting.navigation_menu = "sidebar"

    visit("/")
    chat_page.prefers_drawer

    expect(chat_sidebar_page).to have_channel(public_channel)
    expect(chat_sidebar_page).to have_no_channel(private_channel)

    chat_sidebar_page.open_channel(public_channel)

    expect(chat_drawer_page).to have_open_channel(public_channel)

    chat_drawer_page.join_channel
    expect(login_page).to be_open
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

  it "lets visitors jump from a public thread to its original message" do
    public_channel.update!(threading_enabled: true)
    thread = Fabricate(:chat_thread, channel: public_channel, original_message: existing_message)

    chat_page.visit_thread(thread)
    thread_page.open_original_message

    expect(channel_page.messages).to have_message(id: thread.original_message.id, highlighted: true)
  end
end
