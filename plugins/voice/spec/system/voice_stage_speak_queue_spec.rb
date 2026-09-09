# frozen_string_literal: true

require_relative "../support/voice_fake_media"

# NOTE: outside CI, core pins every test browser to one fixed
# --remote-debugging-port, so these two-session specs need CI=1 in the
# environment to launch the second browser locally.
describe "Voice stage speak queue" do
  fab!(:moderator, :user)
  fab!(:listener, :user)
  fab!(:room) do
    Fabricate(
      :voice_room,
      name: "Stage Room",
      creator: moderator,
      public: true,
      room_type: Voice::Room::ROOM_TYPE_STAGE,
    )
  end

  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    moderator.activate
    listener.activate
    SiteSetting.voice_enabled = true
    SiteSetting.voice_mesh_privacy_warning_enabled = false
    SiteSetting.voice_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.voice_video_enabled = true
  end

  def join_room(user)
    sign_in(user)
    install_voice_fake_media
    visit("/voice/r/#{room.slug}")
    click_button(I18n.t("js.voice.room.join"))
    expect(page).to have_css(".voice-room-page__leave")
  end

  def open_speak_queue
    find("button[data-identifier='voice-speak-queue-menu']").click
  end

  def speak_queue_menu
    ".fk-d-menu[data-identifier='voice-speak-queue-menu']"
  end

  it "promotes the listener to speaker when a moderator approves their request" do
    using_session(:alice) { join_room(moderator) }

    using_session(:bob) do
      join_room(listener)

      expect(page).to have_css(".voice-call-controls__raise-hand")
      find(".voice-call-controls__raise-hand").click
      expect(page).to have_css(".voice-call-controls__raise-hand.--active")
    end

    using_session(:alice) do
      expect(page).to have_css(".voice-speak-queue-trigger__count", text: "1", wait: 10)
      expect(page).to have_css(
        ".sidebar-section[data-section-name='voice-rooms'] .voice-participant-suffix .d-icon-hand",
      )

      open_speak_queue
      within(speak_queue_menu) do
        expect(page).to have_css(".voice-speak-queue__item", text: listener.username)
        expect(page).to have_css(".voice-speak-queue__position", text: "1")
        find(".voice-speak-queue__approve").click
      end
    end

    using_session(:bob) do
      expect(toasts).to have_success(I18n.t("js.voice.stage.promoted_to_speaker"))
      expect(page).to have_no_css(".voice-call-controls__raise-hand")
      expect(page).to have_button(I18n.t("js.voice.video.camera_on"))
    end

    using_session(:alice) do
      within(speak_queue_menu) { expect(page).to have_css(".voice-speak-queue__empty") }
      expect(page).to have_no_css(".voice-speak-queue-trigger__count")
    end
  end

  it "lets the listener raise their hand again after a moderator dismisses the request" do
    using_session(:alice) { join_room(moderator) }

    using_session(:bob) do
      join_room(listener)

      find(".voice-call-controls__raise-hand").click
      expect(page).to have_css(".voice-call-controls__raise-hand.--active")
    end

    using_session(:alice) do
      expect(page).to have_css(".voice-speak-queue-trigger__count", text: "1", wait: 10)

      open_speak_queue
      within(speak_queue_menu) do
        find(".voice-speak-queue__dismiss").click
        expect(page).to have_css(".voice-speak-queue__empty")
      end
      expect(page).to have_no_css(".voice-speak-queue-trigger__count")
    end

    using_session(:bob) do
      expect(toasts).to have_default(I18n.t("js.voice.stage.request_dismissed"))
      expect(page).to have_css(".voice-call-controls__raise-hand:not(.--active)")

      find(".voice-call-controls__raise-hand").click
      expect(page).to have_css(".voice-call-controls__raise-hand.--active")
    end

    using_session(:alice) do
      expect(page).to have_css(".voice-speak-queue-trigger__count", text: "1", wait: 10)
    end
  end

  it "clears the moderator's queue when the listener lowers their own hand" do
    using_session(:alice) { join_room(moderator) }

    using_session(:bob) do
      join_room(listener)

      find(".voice-call-controls__raise-hand").click
      expect(page).to have_css(".voice-call-controls__raise-hand.--active")
    end

    using_session(:alice) do
      expect(page).to have_css(".voice-speak-queue-trigger__count", text: "1", wait: 10)
    end

    using_session(:bob) do
      find(".voice-call-controls__raise-hand.--active").click
      expect(page).to have_css(".voice-call-controls__raise-hand:not(.--active)")
    end

    using_session(:alice) do
      expect(page).to have_no_css(".voice-speak-queue-trigger__count", wait: 10)

      open_speak_queue
      within(speak_queue_menu) { expect(page).to have_css(".voice-speak-queue__empty") }
    end
  end
end
