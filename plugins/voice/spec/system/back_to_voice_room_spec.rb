# frozen_string_literal: true

require_relative "../support/voice_fake_media"

describe "Back to voice room button" do
  include ThemeScreenshotMarker

  fab!(:user)
  fab!(:channel, :chat_channel) { Fabricate(:chat_channel, threading_enabled: true) }

  fab!(:room) do
    Fabricate(:voice_room, name: "Team Room", public: true, chat_channel_id: channel.id)
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }
  let(:back_to_voice_room) { PageObjects::Components::VoiceBackToVoiceRoom.new }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_mesh_privacy_warning_enabled = false
    SiteSetting.voice_chat_enabled = true
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:everyone]
    chat_system_bootstrap(user, [channel])
    sign_in(user)
    install_voice_fake_media
  end

  it "takes the user from a session thread straight into its voice room" do
    session = Voice::ChatSession.post_message!(room, user, "hi from the room")
    thread = Chat::Thread.find(session[:thread_id])

    chat_page.visit_thread(thread)

    expect(back_to_voice_room).to have_back_to_room_button
    screenshot_marker(label: "back-to-voice-room-full-page", only: :desktop)
    back_to_voice_room.click

    expect(page).to have_current_path("/voice/r/#{room.slug}", ignore_query: true)

    # The click joins the call directly — no interstitial join button — and,
    # since this session is still live, arrives with its chat panel open.
    expect(page).to have_button(I18n.t("js.voice.room.leave"))
    expect(page).to have_no_button(I18n.t("js.voice.room.join"))
    expect(page).to have_css(".voice-chat")
  end

  it "shows the button on the drawer thread header" do
    Voice::ChatSession.post_message!(room, user, "hi from the room")
    session = Voice::ChatSession.post_message!(room, user, "and a reply")
    thread = Chat::Thread.find(session[:thread_id])

    chat_drawer_page.visit_channel(channel)
    channel_page.message_thread_indicator(thread.original_message).click

    expect(chat_drawer_page).to have_open_thread(thread)
    expect(back_to_voice_room).to have_back_to_room_button
    screenshot_marker(label: "back-to-voice-room-drawer", only: :desktop)
  end

  it "hides the button on a thread that is not a voice-room session" do
    thread = Fabricate(:chat_thread, channel: channel)

    chat_page.visit_thread(thread)

    expect(back_to_voice_room).to have_no_back_to_room_button
  end
end
