# frozen_string_literal: true

require_relative "../support/live_fake_media"

# NOTE: outside CI, core pins every test browser to one fixed
# --remote-debugging-port, so these two-session specs need CI=1 in the
# environment to launch the second browser locally.
describe "Live stage speak queue" do
  fab!(:moderator, :user)
  fab!(:listener, :user)
  fab!(:room) do
    Fabricate(
      :live_room,
      name: "Stage Room",
      creator: moderator,
      public: true,
      room_type: Live::Room::ROOM_TYPE_STAGE,
    )
  end

  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    moderator.activate
    listener.activate
    SiteSetting.live_enabled = true
    SiteSetting.live_mesh_privacy_warning_enabled = false
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
  end

  def join_room(user)
    sign_in(user)
    install_live_fake_media
    visit("/live/r/#{room.slug}")
    click_button(I18n.t("js.live.room.join"))
    expect(page).to have_css(".live-room-page__leave")
  end

  def open_speak_queue
    find("button[data-identifier='live-speak-queue-menu']").click
  end

  def speak_queue_menu
    ".fk-d-menu[data-identifier='live-speak-queue-menu']"
  end

  it "promotes the listener to speaker when a moderator approves their request" do
    using_session(:alice) { join_room(moderator) }

    using_session(:bob) do
      join_room(listener)

      expect(page).to have_css(".live-call-controls__raise-hand")
      find(".live-call-controls__raise-hand").click
      expect(page).to have_css(".live-call-controls__raise-hand.--active")
    end

    using_session(:alice) do
      expect(page).to have_css(".live-speak-queue-trigger__count", text: "1", wait: 10)
      expect(page).to have_css(
        ".sidebar-section[data-section-name='live-rooms'] .live-participant-suffix .d-icon-hand",
      )

      open_speak_queue
      within(speak_queue_menu) do
        expect(page).to have_css(".live-speak-queue__item", text: listener.username)
        expect(page).to have_css(".live-speak-queue__position", text: "1")
        find(".live-speak-queue__approve").click
      end
    end

    using_session(:bob) do
      expect(toasts).to have_success(I18n.t("js.live.stage.promoted_to_speaker"))
      expect(page).to have_no_css(".live-call-controls__raise-hand")
      expect(page).to have_button(I18n.t("js.live.video.camera_on"))
    end

    using_session(:alice) do
      within(speak_queue_menu) { expect(page).to have_css(".live-speak-queue__empty") }
      expect(page).to have_no_css(".live-speak-queue-trigger__count")
    end
  end

  it "makes the listener wait before raising their hand again after a moderator dismisses the request" do
    using_session(:alice) { join_room(moderator) }

    using_session(:bob) do
      join_room(listener)

      find(".live-call-controls__raise-hand").click
      expect(page).to have_css(".live-call-controls__raise-hand.--active")
    end

    using_session(:alice) do
      expect(page).to have_css(".live-speak-queue-trigger__count", text: "1", wait: 10)

      open_speak_queue
      within(speak_queue_menu) do
        find(".live-speak-queue__dismiss").click
        expect(page).to have_css(".live-speak-queue__empty")
      end
      expect(page).to have_no_css(".live-speak-queue-trigger__count")
    end

    using_session(:bob) do
      expect(toasts).to have_default(I18n.t("js.live.stage.request_dismissed"))
      expect(page).to have_css(".live-call-controls__raise-hand:not(.--active)")

      find(".live-call-controls__raise-hand").click
      expect(page).to have_css(".dialog-body", text: /ask again in \d+ seconds/)
      find(".dialog-footer .btn-primary").click
      expect(page).to have_css(".live-call-controls__raise-hand:not(.--active)")

      Discourse.redis.del(*Discourse.redis.keys("*hand_cooldown*"))
      find(".live-call-controls__raise-hand").click
      expect(page).to have_css(".live-call-controls__raise-hand.--active")
    end

    using_session(:alice) do
      expect(page).to have_css(".live-speak-queue-trigger__count", text: "1", wait: 10)
    end
  end

  it "clears the moderator's queue when the listener lowers their own hand" do
    using_session(:alice) { join_room(moderator) }

    using_session(:bob) do
      join_room(listener)

      find(".live-call-controls__raise-hand").click
      expect(page).to have_css(".live-call-controls__raise-hand.--active")
    end

    using_session(:alice) do
      expect(page).to have_css(".live-speak-queue-trigger__count", text: "1", wait: 10)
    end

    using_session(:bob) do
      find(".live-call-controls__raise-hand.--active").click
      expect(page).to have_css(".live-call-controls__raise-hand:not(.--active)")
    end

    using_session(:alice) do
      expect(page).to have_no_css(".live-speak-queue-trigger__count", wait: 10)

      open_speak_queue
      within(speak_queue_menu) { expect(page).to have_css(".live-speak-queue__empty") }
    end
  end

  def invite_to_speak(user)
    Live::ParticipantTracker.invite_to_speak(room.id, user.id)
    Live::RoomBroadcaster.publish_speak_invitation(room, user.id, invited: true, reason: "invited")
    Live::RoomBroadcaster.publish_participants(room)
  end

  it "lets an invited listener accept and take the stage" do
    using_session(:alice) { join_room(moderator) }

    using_session(:bob) do
      join_room(listener)
      expect(page).to have_css(".live-call-controls__raise-hand")

      invite_to_speak(listener)

      expect(page).to have_css(".live-call-controls__accept-invitation", wait: 10)
      expect(page).to have_no_css(".live-call-controls__raise-hand")

      find(".live-call-controls__accept-invitation").click

      expect(toasts).to have_success(I18n.t("js.live.stage.promoted_to_speaker"))
      expect(page).to have_no_css(".live-call-controls__accept-invitation")
      expect(page).to have_button(I18n.t("js.live.video.camera_on"))
    end

    expect(room.room_memberships.find_by(user: listener)).to have_attributes(
      speaker?: true,
      session_only: true,
    )
  end

  it "returns the listener to raising their hand when they decline an invitation" do
    using_session(:alice) { join_room(moderator) }

    using_session(:bob) do
      join_room(listener)
      invite_to_speak(listener)

      expect(page).to have_css(".live-call-controls__decline-invitation", wait: 10)
      find(".live-call-controls__decline-invitation").click

      expect(page).to have_no_css(".live-call-controls__accept-invitation")
      expect(page).to have_css(".live-call-controls__raise-hand")
    end

    expect(room.room_memberships.find_by(user: listener)).to be_nil
  end

  it "takes the stage controls away from a speaker who is moved back to listeners" do
    using_session(:alice) { join_room(moderator) }

    using_session(:bob) do
      join_room(listener)
      find(".live-call-controls__raise-hand").click
      expect(page).to have_css(".live-call-controls__raise-hand.--active")
    end

    using_session(:alice) do
      expect(page).to have_css(".live-speak-queue-trigger__count", text: "1", wait: 10)
      open_speak_queue
      within(speak_queue_menu) { find(".live-speak-queue__approve").click }
    end

    using_session(:bob) { expect(page).to have_button(I18n.t("js.live.video.camera_on"), wait: 10) }

    Live::StageRoles.remove!(room, room.room_memberships.find_by(user: listener))

    using_session(:bob) do
      expect(toasts).to have_default(I18n.t("js.live.stage.demoted_to_listener"))
      expect(page).to have_css(".live-call-controls__raise-hand", wait: 10)
      expect(page).to have_no_button(I18n.t("js.live.video.camera_on"))
    end
  end

  it "does not keep a raised hand across leaving and rejoining the call" do
    using_session(:alice) { join_room(moderator) }

    using_session(:bob) do
      join_room(listener)
      find(".live-call-controls__raise-hand").click
      expect(page).to have_css(".live-call-controls__raise-hand.--active")
    end

    using_session(:alice) do
      expect(page).to have_css(".live-speak-queue-trigger__count", text: "1", wait: 10)
    end

    using_session(:bob) do
      find(".live-room-page__leave").click
      expect(page).to have_button(I18n.t("js.live.room.join"))
      click_button(I18n.t("js.live.room.join"))
      expect(page).to have_css(".live-room-page__leave")
      expect(page).to have_css(".live-call-controls__raise-hand:not(.--active)")
    end

    using_session(:alice) do
      expect(page).to have_no_css(".live-speak-queue-trigger__count", wait: 10)
    end
  end

  it "hides the raise hand button when the room does not take requests to speak" do
    room.update!(speak_requests_enabled: false)

    using_session(:alice) { join_room(moderator) }

    using_session(:bob) do
      join_room(listener)

      # The decline button only renders once the roster has made this user a
      # listener, so the absence check below cannot pass before the controls
      # have rendered.
      invite_to_speak(listener)
      expect(page).to have_css(".live-call-controls__decline-invitation", wait: 10)
      find(".live-call-controls__decline-invitation").click

      expect(page).to have_no_css(".live-call-controls__decline-invitation")
      expect(page).to have_no_css(".live-call-controls__raise-hand")
    end
  end
end
