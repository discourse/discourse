# frozen_string_literal: true

require_relative "../support/voice_fake_media"

describe "Voice room chat panel" do
  fab!(:user)
  fab!(:admin)
  fab!(:channel, :chat_channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:room) do
    Fabricate(
      :voice_room,
      name: "Team Room",
      creator: admin,
      public: true,
      chat_channel_id: channel.id,
      chat_idle_minutes: 15,
    )
  end

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_mesh_privacy_warning_enabled = false
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:everyone]
    chat_system_bootstrap(user, [channel])
    sign_in(user)
    install_voice_fake_media
  end

  it "renders an existing session thread through chat's own thread UI and posts through it" do
    Voice::ChatSession.post_message!(room, admin, "hi from admin")

    visit("/voice/r/#{room.slug}?chat=true")
    click_button(I18n.t("js.voice.room.join"))
    # The panel slides in; typing into it mid-animation can miss the composer.
    wait_for_animation(find(".voice-room-page__sidebar"))

    # The real chat thread component, not a re-implementation.
    expect(page).to have_css(".voice-chat .chat-thread")
    expect(page).to have_css(".voice-chat .chat-message-text", text: "hi from admin")

    # The native composer posts through chat's own API.
    find(".voice-chat .chat-composer__input").fill_in(with: "hello from the room")
    find(".voice-chat .chat-composer__input").send_keys(:enter)

    expect(page).to have_css(".voice-chat .chat-message-text", text: "hello from the room")

    # The message renders staged before the create request lands — wait for
    # the server to actually persist it.
    try_until_success do
      expect(
        Chat::Message.where(chat_channel_id: channel.id).order(:created_at).last&.message,
      ).to eq("hello from the room")
    end
  end

  it "opens the chat panel by default after joining a stage room" do
    stage_room =
      Fabricate(
        :voice_room,
        name: "Stage Team Room",
        creator: admin,
        public: true,
        room_type: Voice::Room::ROOM_TYPE_STAGE,
        chat_channel_id: channel.id,
      )

    visit("/voice/r/#{stage_room.slug}")
    click_button(I18n.t("js.voice.room.join"))

    expect(page).to have_css(".voice-room-page__sidebar .voice-chat")
    expect(page).to have_current_path("/voice/r/#{stage_room.slug}")
  end

  it "keeps the chat panel closed by default after joining an open room" do
    visit("/voice/r/#{room.slug}")
    click_button(I18n.t("js.voice.room.join"))

    expect(page).to have_css(".voice-room-page__leave")
    expect(page).to have_no_css(".voice-room-page__sidebar")
  end

  it "opens the session thread from the first message sent through the starter composer" do
    visit("/voice/r/#{room.slug}?chat=true")
    click_button(I18n.t("js.voice.room.join"))
    # The panel slides in; typing into it mid-animation can miss the composer.
    wait_for_animation(find(".voice-room-page__sidebar"))

    # No thread yet: the panel offers the starter composer, not the thread UI.
    expect(page).to have_css(".voice-chat__input")
    expect(page).to have_no_css(".voice-chat .chat-thread")

    find(".voice-chat__input").fill_in(with: "kicking things off")
    # See the note above: the first send races thread creation, its message
    # fetch, and the native composer's mount/focus against the settle check.
    using_wait_time(20) { find(".voice-chat__input").send_keys(:enter) }

    # The first message creates the thread and the panel swaps to the native UI.
    expect(page).to have_css(".voice-chat .chat-thread")
    expect(page).to have_css(".voice-chat .chat-message-text", text: "kicking things off")

    thread = Chat::Thread.find_by(channel_id: channel.id)
    expect(thread.original_message.message).to eq("In ##{room.slug}::room - kicking things off")
    expect(thread.original_message.user_id).to eq(user.id)
  end
end
