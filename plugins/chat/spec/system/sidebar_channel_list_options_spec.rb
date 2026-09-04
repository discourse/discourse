# frozen_string_literal: true

RSpec.describe "Chat sidebar channel list options" do
  fab!(:current_user, :user)
  fab!(:read_channel) { Fabricate(:category_channel, name: "Alpha channel") }
  fab!(:unread_channel) { Fabricate(:category_channel, name: "Zulu channel") }
  fab!(:message_author, :user)

  let(:chat_sidebar) { PageObjects::Pages::ChatSidebar.new }

  before do
    read_message =
      Fabricate(
        :chat_message,
        chat_channel: read_channel,
        user: message_author,
        created_at: 2.days.ago,
      )
    read_channel.update!(last_message: read_message, messages_count: 1)

    chat_system_bootstrap(current_user, [read_channel, unread_channel])

    unread_message =
      Fabricate(
        :chat_message,
        chat_channel: unread_channel,
        user: message_author,
        created_at: 1.hour.ago,
      )
    unread_channel.update!(last_message: unread_message, messages_count: 1)

    SiteSetting.navigation_menu = "sidebar"
    sign_in(current_user)
  end

  it "sorts, filters, and persists the user's choices" do
    visit("/")

    expect(chat_sidebar.channel_names).to eq(["Alpha channel", "Zulu channel"])

    chat_sidebar.set_channel_sort("recent_activity")

    try_until_success(reason: "channel list re-sorts after the menu closes") do
      expect(chat_sidebar.channel_names).to eq(["Zulu channel", "Alpha channel"])
    end
    try_until_success(reason: "channel sort preference saves asynchronously") do
      expect(current_user.user_option.reload.chat_channel_list_sort).to eq("recent_activity")
    end

    chat_sidebar.set_channel_filter("unread")

    expect(chat_sidebar).to have_channel(unread_channel)
    expect(chat_sidebar).to have_no_channel(read_channel)
    try_until_success(reason: "channel filter preference saves asynchronously") do
      expect(current_user.user_option.reload.chat_channel_list_filter).to eq("unread")
    end

    page.refresh

    expect(chat_sidebar).to have_channel(unread_channel)
    expect(chat_sidebar).to have_no_channel(read_channel)
    expect(chat_sidebar.channel_names).to eq(["Zulu channel"])

    chat_sidebar.set_channel_filter("mentions")

    expect(page).to have_css(
      ".chat-sidebar-channels-filter-empty-state",
      text: "No channels match this filter.",
    )

    chat_sidebar.show_all_channels

    expect(chat_sidebar).to have_channel(unread_channel)
    expect(chat_sidebar).to have_channel(read_channel)
    try_until_success(reason: "reset channel filter preference saves asynchronously") do
      expect(current_user.user_option.reload.chat_channel_list_filter).to eq("all")
    end
  end
end
