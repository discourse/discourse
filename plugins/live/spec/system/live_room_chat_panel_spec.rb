# frozen_string_literal: true

require_relative "../support/live_fake_media"

describe "Live room chat panel" do
  fab!(:user)
  fab!(:admin)
  fab!(:channel, :chat_channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:room) do
    Fabricate(
      :live_room,
      name: "Team Room",
      creator: admin,
      public: true,
      chat_channel_id: channel.id,
      chat_idle_minutes: 15,
    )
  end

  let(:chat_panel) { PageObjects::Components::LiveRoomChatPanel.new }

  before do
    SiteSetting.chat_allow_uploads = true
    SiteSetting.live_enabled = true
    SiteSetting.live_mesh_privacy_warning_enabled = false
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    chat_system_bootstrap(user, [channel])
    sign_in(user)
    install_live_fake_media
  end

  it "renders an existing session thread through chat's own thread UI and posts through it" do
    Live::ChatSession.post_message!(room, admin, "hi from admin")

    visit("/live/r/#{room.slug}?chat=true")
    click_button(I18n.t("js.live.room.join"))
    # The panel slides in; typing into it mid-animation can miss the composer.
    wait_for_animation(find(".chat-side-panel"))

    # The real chat thread component, not a re-implementation.
    expect(page).to have_css(".live-chat .chat-thread")
    expect(page).to have_css(".live-chat .chat-message-text", text: "hi from admin")

    # The native composer posts through chat's own API.
    find(".live-chat .chat-composer__input").fill_in(with: "hello from the room")
    find(".live-chat .chat-composer__input").send_keys(:enter)

    expect(page).to have_css(".live-chat .chat-message-text", text: "hello from the room")

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
        :live_room,
        name: "Stage Team Room",
        creator: admin,
        public: true,
        room_type: Live::Room::ROOM_TYPE_STAGE,
        chat_channel_id: channel.id,
      )

    visit("/live/r/#{stage_room.slug}")
    click_button(I18n.t("js.live.room.join"))

    expect(page).to have_css(".chat-side-panel .live-chat")
    expect(page).to have_current_path("/live/r/#{stage_room.slug}")
  end

  it "keeps the chat panel closed by default after joining an open room" do
    visit("/live/r/#{room.slug}")
    click_button(I18n.t("js.live.room.join"))

    expect(page).to have_css(".live-room-page__leave")
    expect(page).to have_no_css(".chat-side-panel")
  end

  it "lets the user start a conversation with the full composer" do
    visit("/live/r/#{room.slug}?chat=true")
    click_button(I18n.t("js.live.room.join"))
    wait_for_animation(find(".chat-side-panel"))

    expect(chat_panel).to have_toolbar
    chat_panel.compose("kicking things off").send_message

    expect(chat_panel).to have_thread
    expect(chat_panel).to have_message("kicking things off")
    chat_panel.compose("a follow-up").send_message
    expect(chat_panel).to have_message("a follow-up")
  end

  it "lets the user start a conversation with an attachment" do
    visit("/live/r/#{room.slug}?chat=true")
    click_button(I18n.t("js.live.room.join"))
    wait_for_animation(find(".chat-side-panel"))

    chat_panel.attach(file_from_fixtures("logo.png").path)
    expect(chat_panel).to have_attachment
    chat_panel.send_message

    expect(chat_panel).to have_thread
    expect(chat_panel).to have_image_message
  end

  it "keeps the user's draft when another participant starts the conversation" do
    visit("/live/r/#{room.slug}?chat=true")
    click_button(I18n.t("js.live.room.join"))
    wait_for_animation(find(".chat-side-panel"))
    chat_panel.compose("my unfinished message")

    using_session(:other_participant) do
      sign_in(admin)
      install_live_fake_media
      visit("/live/r/#{room.slug}?chat=true")
      click_button(I18n.t("js.live.room.join"))
      wait_for_animation(find(".chat-side-panel"))
      chat_panel.compose("hello from the other participant").send_message
      expect(chat_panel).to have_thread
    end

    expect(chat_panel).to have_thread
    expect(chat_panel).to have_message("hello from the other participant")
    expect(chat_panel).to have_draft("my unfinished message")
    chat_panel.send_message
    expect(chat_panel).to have_message("my unfinished message")
  end
end
