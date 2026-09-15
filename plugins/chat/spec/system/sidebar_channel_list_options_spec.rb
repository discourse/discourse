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

  it "puts unread channels first, alphabetically, ahead of read channels" do
    # Bravo is unread but older than Alpha's last message, so it separates
    # "unread first" from "recent activity", which would place it last.
    older_unread_channel = Fabricate(:category_channel, name: "Bravo channel")
    older_unread_channel.add(current_user)
    older_unread_message =
      Fabricate(
        :chat_message,
        chat_channel: older_unread_channel,
        user: message_author,
        created_at: 3.days.ago,
      )
    older_unread_channel.update!(last_message: older_unread_message, messages_count: 1)

    visit("/")

    chat_sidebar.set_channel_sort("unread_first")

    try_until_success(reason: "channel list re-sorts after the menu closes") do
      expect(chat_sidebar.channel_names).to eq(["Bravo channel", "Zulu channel", "Alpha channel"])
    end
    try_until_success(reason: "channel sort preference saves asynchronously") do
      expect(current_user.user_option.reload.chat_channel_list_sort).to eq("unread_first")
    end

    page.refresh

    expect(chat_sidebar.channel_names).to eq(["Bravo channel", "Zulu channel", "Alpha channel"])
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
    expect(page).to have_no_css("[data-sidebar-action-id='toggleChannelFilter']")

    chat_sidebar.set_channel_filter("mentions")

    expect(page).to have_no_css(".chat-sidebar-channels-filter-empty-state")
    expect(page).to have_css(
      "[data-sidebar-action-id='toggleChannelFilter'] .d-icon-filter-circle-xmark",
    )

    chat_sidebar.toggle_channel_filter

    expect(chat_sidebar).to have_channel(unread_channel)
    expect(chat_sidebar).to have_channel(read_channel)
    try_until_success(reason: "temporary override retains the saved filter") do
      expect(current_user.user_option.reload.chat_channel_list_filter).to eq("mentions")
    end

    expect(chat_sidebar.channel_names).to eq(["Zulu channel", "Alpha channel"])
    expect(page).to have_css("[data-sidebar-action-id='toggleChannelFilter'] .d-icon-filter")
    chat_sidebar.toggle_channel_filter
    expect(chat_sidebar).to have_no_channel(read_channel)
    expect(chat_sidebar).to have_no_channel(unread_channel)
    chat_sidebar.toggle_channel_filter
    page.refresh
    expect(chat_sidebar).to have_no_channel(read_channel)
    expect(chat_sidebar).to have_no_channel(unread_channel)
  end

  it "opens the new channel modal for staff from the channels options menu" do
    current_user.update!(admin: true)
    visit("/")

    menu = chat_sidebar.open_channel_list_options
    menu.option('[data-menu-option-id="createChannel"]').click

    expect(page).to have_css(".chat-modal-create-channel")
  end

  it "keeps the starred section visible when the starred filter hides its channels" do
    read_channel.membership_for(current_user).update!(starred: true)

    visit("/")

    within(chat_sidebar.starred_section) { expect(page).to have_css(".channel-#{read_channel.id}") }

    chat_sidebar.set_starred_filter("unread")

    within(chat_sidebar.starred_section) do
      expect(page).to have_no_css(".channel-#{read_channel.id}")
    end
    expect(page).to have_css(".sidebar-section[data-section-name='chat-starred-channels']")
    try_until_success(reason: "starred filter preference saves asynchronously") do
      expect(current_user.user_option.reload.chat_channel_list_filter_starred).to eq("unread")
    end

    chat_sidebar.toggle_channel_filter

    within(chat_sidebar.starred_section) { expect(page).to have_css(".channel-#{read_channel.id}") }
    try_until_success(reason: "temporary override retains the starred filter") do
      expect(current_user.user_option.reload.chat_channel_list_filter_starred).to eq("unread")
    end
  end

  it "hides the starred section when a filter is set but nothing is starred" do
    current_user.user_option.update!(chat_channel_list_filter_starred: "unread")

    visit("/")

    expect(chat_sidebar).to have_no_starred_channels_section
  end

  it "keeps the DM section visible when the DM filter hides its channels" do
    dm_channel = Fabricate(:direct_message_channel, users: [current_user, message_author])

    visit("/")

    within(chat_sidebar.dms_section) { expect(page).to have_css(".channel-#{dm_channel.id}") }

    chat_sidebar.set_dm_filter("unread")

    within(chat_sidebar.dms_section) { expect(page).to have_no_css(".channel-#{dm_channel.id}") }
    expect(page).to have_css(".sidebar-section[data-section-name='chat-dms']")
    try_until_success(reason: "DM filter preference saves asynchronously") do
      expect(current_user.user_option.reload.chat_channel_list_filter_dms).to eq("unread")
    end

    chat_sidebar.toggle_channel_filter

    within(chat_sidebar.dms_section) { expect(page).to have_css(".channel-#{dm_channel.id}") }
    try_until_success(reason: "temporary override retains the DM filter") do
      expect(current_user.user_option.reload.chat_channel_list_filter_dms).to eq("unread")
    end
  end
end
