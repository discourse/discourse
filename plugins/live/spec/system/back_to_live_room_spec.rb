# frozen_string_literal: true

require_relative "../support/live_fake_media"

describe "Back to live room button" do
  include ThemeScreenshotMarker

  fab!(:user)
  fab!(:channel, :chat_channel) { Fabricate(:chat_channel, threading_enabled: true) }

  fab!(:room) do
    Fabricate(:live_room, name: "Team Room", public: true, chat_channel_id: channel.id)
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }
  let(:back_to_live_room) { PageObjects::Components::LiveBackToLiveRoom.new }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_mesh_privacy_warning_enabled = false
    SiteSetting.live_chat_enabled = true
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    chat_system_bootstrap(user, [channel])
    sign_in(user)
    install_live_fake_media
  end

  it "takes the user from a session thread straight into its live room" do
    session = Live::ChatSession.post_message!(room, user, "hi from the room")
    thread = Chat::Thread.find(session[:thread_id])

    chat_page.visit_thread(thread)

    expect(back_to_live_room).to have_back_to_room_button
    screenshot_marker(label: "back-to-live-room-full-page", only: :desktop)
    back_to_live_room.click

    expect(page).to have_current_path("/live/r/#{room.slug}", ignore_query: true)

    # The click joins the call directly — no interstitial join button — and,
    # since this session is still live, arrives with its chat panel open.
    expect(page).to have_button(I18n.t("js.live.room.leave"))
    expect(page).to have_no_button(I18n.t("js.live.room.join"))
    expect(page).to have_css(".live-chat")
  end

  it "shows the button on the drawer thread header" do
    Live::ChatSession.post_message!(room, user, "hi from the room")
    session = Live::ChatSession.post_message!(room, user, "and a reply")
    thread = Chat::Thread.find(session[:thread_id])

    chat_drawer_page.visit_channel(channel)
    channel_page.message_thread_indicator(thread.original_message).click

    expect(chat_drawer_page).to have_open_thread(thread)
    expect(back_to_live_room).to have_back_to_room_button
    screenshot_marker(label: "back-to-live-room-drawer", only: :desktop)
  end

  it "hides the button on a thread that is not a live-room session" do
    thread = Fabricate(:chat_thread, channel: channel)

    chat_page.visit_thread(thread)

    expect(back_to_live_room).to have_no_back_to_room_button
  end
end
