import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import VoiceRoomPage from "discourse/plugins/voice/discourse/components/voice/room-page";

class VoiceRoomsStub extends Service {
  @tracked rooms = [];

  roomById(id) {
    return this.rooms.find((room) => Number(room.id) === Number(id));
  }

  isParticipantSpeaking() {
    return false;
  }
}

class VoiceWebrtcStub extends Service {
  @tracked activeRoomId = 1;
  @tracked audioEnabled = true;
  @tracked deafened = false;
  @tracked localVideoKind = null;
  @tracked pttEnabled = false;

  screenShareSupported = true;

  get activeRoom() {
    return this.voiceRooms.roomById(this.activeRoomId);
  }

  connectionStateFor() {
    return "connected";
  }

  videoAllowedIn() {
    return true;
  }

  canPublishVideo() {
    return true;
  }

  isActiveRoom() {
    return false;
  }

  isTranscribingRoom() {
    return false;
  }

  setWatching() {}
  join() {}
  leave() {}
  toggleMute() {}
  toggleDeafen() {}
  toggleCamera() {}
  toggleScreenShare() {}
  attachVideoStream() {}
  getParticipantVolume() {
    return 1;
  }

  isParticipantMuted() {
    return false;
  }

  remoteStreamFor() {
    return { id: "stream" };
  }
}

class RouterStub extends Service {
  transitionTo() {}
}

class ModalStub extends Service {
  show() {}
}

class CapabilitiesStub extends Service {
  viewport = { md: true };
  touch = false;
}

async function selectParticipantFromOpenMenu(owner) {
  const menuService = owner.lookup("service:menu");
  const menu = menuService.getByIdentifier("voice-participant-menu");
  menu.options.data.onSpotlight(menu.options.data.participant.id);
  await menuService.close(menu);
}

module("Integration | Component | Voice | RoomPage", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.currentUser = logIn(this.owner);

    this.owner.unregister("service:capabilities");
    this.owner.register("service:capabilities", CapabilitiesStub);
    this.owner.unregister("service:voice-rooms");
    this.owner.register("service:voice-rooms", VoiceRoomsStub);
    this.owner.unregister("service:voice-webrtc");
    this.owner.register("service:voice-webrtc", VoiceWebrtcStub);
    this.owner.unregister("service:router");
    this.owner.register("service:router", RouterStub);
    this.owner.unregister("service:modal");
    this.owner.register("service:modal", ModalStub);

    this.voiceRooms = this.owner.lookup("service:voice-rooms");
    this.voiceWebrtc = this.owner.lookup("service:voice-webrtc");
    this.voiceWebrtc.voiceRooms = this.voiceRooms;

    this.room = {
      id: 1,
      slug: "test-room",
      name: "Test Room",
      chat_available: true,
      video_enabled: true,
      description_excerpt: "Room description",
      active_participants: [
        {
          id: this.currentUser.id,
          username: this.currentUser.username,
          avatar_template: "/letter_avatar_proxy/v4/letter/a/{size}.png",
        },
        {
          id: 2,
          username: "bob",
          avatar_template: "/letter_avatar_proxy/v4/letter/b/{size}.png",
          is_video_on: true,
        },
        {
          id: 3,
          username: "cara",
          avatar_template: "/letter_avatar_proxy/v4/letter/c/{size}.png",
          is_video_on: true,
        },
      ],
    };

    this.voiceRooms.rooms = [this.room];
  });

  test("defaults to the tiled layout with the layout switcher available", async function (assert) {
    await render(<template><VoiceRoomPage @room={{this.room}} /></template>);

    assert
      .dom(".voice-room-page")
      .hasClass("--tiled", "defaults to tiled layout");
    assert.dom(".voice-room-page__grid").exists("renders the tiled grid");

    // The layout switcher lives behind the overflow menu. Switching layouts
    // through the nested `menu`-service submenu needs the app's modal/portal
    // outlets, so the end-to-end switch is covered by a system spec.
    await click(".voice-room-menu-trigger");
    assert
      .dom(".voice-room-page__layout-trigger")
      .exists("exposes the layout switcher in the overflow menu");
  });

  test("a stage room defaults to the presentation layout", async function (assert) {
    this.room.room_type = "stage";
    // Keep the chat panel out of this test; the chat-open default is covered
    // separately.
    this.room.chat_available = false;

    await render(<template><VoiceRoomPage @room={{this.room}} /></template>);

    assert
      .dom(".voice-room-page")
      .hasClass("--presentation", "stage rooms default to presentation");
    assert
      .dom(".voice-room-page")
      .doesNotHaveClass("--tiled", "the tiled default no longer applies");
    assert
      .dom(".voice-room-page__presentation")
      .exists("renders the featured-presenter layout");
  });

  test("presentation layout automatically features the first screen share", async function (assert) {
    this.room.room_type = "stage";
    this.room.chat_available = false;
    this.room.active_participants[1].is_screen_sharing = true;
    this.room.active_participants[2].is_screen_sharing = true;

    await render(<template><VoiceRoomPage @room={{this.room}} /></template>);

    assert
      .dom(
        ".voice-room-page__presentation-main .voice-video-tile[data-user-id='2']"
      )
      .exists("automatically features the first screen share");
    assert
      .dom(
        ".voice-room-page__presentation-rail .voice-video-tile[data-user-id='3']"
      )
      .exists("keeps the other screen share in the rail");
  });

  test("spotlights a selected participant for the viewer", async function (assert) {
    this.room.active_participants[1].is_screen_sharing = true;
    this.room.active_participants[2].is_screen_sharing = true;

    await render(<template><VoiceRoomPage @room={{this.room}} /></template>);

    await click(".voice-video-tile[data-user-id='3'] .voice-video-tile__menu");
    await selectParticipantFromOpenMenu(this.owner);
    await settled();

    assert
      .dom(".voice-room-page")
      .hasClass("--presentation", "switches to presentation layout");
    assert
      .dom(
        ".voice-room-page__presentation-main .voice-video-tile[data-user-id='3']"
      )
      .exists("features the selected screen share");

    await click(".voice-room-page__presentation-main .voice-video-tile__menu");
    const participantMenu = this.owner
      .lookup("service:menu")
      .getByIdentifier("voice-participant-menu");
    assert.true(
      participantMenu.options.data.isSpotlighted,
      "marks the spotlight as active"
    );
    await selectParticipantFromOpenMenu(this.owner);
    await settled();

    assert
      .dom(
        ".voice-room-page__presentation-main .voice-video-tile[data-user-id='2']"
      )
      .exists("returns to automatic screen-share selection");
  });

  test("the normal presentation layout control restores automatic selection", async function (assert) {
    this.room.active_participants[1].is_screen_sharing = true;
    this.room.active_participants[2].is_screen_sharing = true;

    await render(<template><VoiceRoomPage @room={{this.room}} /></template>);

    await click(".voice-video-tile[data-user-id='3'] .voice-video-tile__menu");
    await selectParticipantFromOpenMenu(this.owner);
    await settled();
    await click(".voice-room-menu-trigger");
    await click(".voice-room-page__layout-trigger");

    this.owner
      .lookup("service:menu")
      .getByIdentifier("voice-call-submenu")
      .options.data.onSelect("presentation");
    await settled();

    assert
      .dom(
        ".voice-room-page__presentation-main .voice-video-tile[data-user-id='2']"
      )
      .exists("the default control restores automatic selection");
  });

  test("a spotlighted publisher receives the mobile video budget", async function (assert) {
    this.owner.lookup("service:capabilities").viewport.md = false;
    this.room.active_participants.push(
      ...[4, 5, 6].map((id) => ({
        id,
        username: `user${id}`,
        avatar_template: `/letter_avatar_proxy/v4/letter/u/{size}.png`,
        is_video_on: true,
      }))
    );

    await render(<template><VoiceRoomPage @room={{this.room}} /></template>);

    assert
      .dom(".voice-video-tile[data-user-id='6']")
      .hasClass("--avatar", "the last publisher starts outside the budget");

    await click(".voice-video-tile[data-user-id='6'] .voice-video-tile__menu");
    await selectParticipantFromOpenMenu(this.owner);
    await settled();

    assert
      .dom(
        ".voice-room-page__presentation-main .voice-video-tile[data-user-id='6']"
      )
      .hasClass("--video", "the spotlighted publisher receives live video");
  });

  test("falls back when the spotlighted participant leaves", async function (assert) {
    this.room.active_participants[1].is_screen_sharing = true;
    this.room.active_participants[2].is_screen_sharing = true;

    await render(<template><VoiceRoomPage @room={{this.room}} /></template>);
    await click(".voice-video-tile[data-user-id='3'] .voice-video-tile__menu");
    await selectParticipantFromOpenMenu(this.owner);
    await settled();

    this.voiceRooms.rooms = [
      {
        ...this.room,
        active_participants: this.room.active_participants.filter(
          (participant) => participant.id !== 3
        ),
      },
    ];
    await settled();

    assert
      .dom(
        ".voice-room-page__presentation-main .voice-video-tile[data-user-id='2']"
      )
      .exists("falls back to automatic selection");

    this.voiceRooms.rooms = [this.room];
    await settled();

    assert
      .dom(
        ".voice-room-page__presentation-main .voice-video-tile[data-user-id='2']"
      )
      .exists("does not restore a stale spotlight if the participant rejoins");
  });

  test("a joined stage room with chat available opens the chat panel by default", async function (assert) {
    // The panel prepares its chat session on mount; an empty payload keeps it
    // in the pre-thread composer state without touching chat internals.
    pretender.post("/voice/rooms/1/chat_session", () => response({}));

    this.room.room_type = "stage";

    await render(<template><VoiceRoomPage @room={{this.room}} /></template>);

    assert
      .dom(".voice-room-page")
      .hasClass("--chat-open", "the chat panel is open by default");
    assert.dom(".voice-chat").exists("mounts the chat panel");
  });
});
