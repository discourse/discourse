import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import {
  click,
  render,
  settled,
  triggerEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import VoiceCallWidget from "discourse/plugins/voice/discourse/components/voice/call-widget";

class VoiceRoomsStub extends Service {
  @tracked rooms = [];

  roomById(id) {
    return this.rooms.find((room) => Number(room.id) === Number(id));
  }

  setParticipants(roomId, participants) {
    this.rooms = this.rooms.map((room) => {
      if (Number(room.id) !== Number(roomId)) {
        return room;
      }

      return { ...room, active_participants: participants };
    });
  }

  isParticipantSpeaking() {
    return false;
  }
}

class VoiceWebrtcStub extends Service {
  @tracked activeRoomId = 1;
  @tracked audioEnabled = true;
  @tracked callWidgetHidden = false;
  @tracked deafened = false;
  @tracked localVideoKind = null;
  @tracked pttEnabled = false;

  screenShareSupported = false;
  watchingCalls = [];
  videoStreams = new Map();
  leaveCalls = [];

  get activeRoom() {
    return this.voiceRooms.roomById(this.activeRoomId);
  }

  videoAllowedIn() {
    return true;
  }

  canPublishVideo() {
    return true;
  }

  connectionStateFor() {
    return "connected";
  }

  isTranscribingRoom() {
    return false;
  }

  remoteStreamFor(roomId, userId) {
    return this.videoStreams.get(`${roomId}:${userId}`);
  }

  setWatching(roomId, watching, options = {}) {
    this.watchingCalls.push({ roomId, watching, options });
  }

  attachVideoStream() {}
  toggleMute() {}
  toggleDeafen() {}
  toggleCamera() {}
  toggleScreenShare() {}
  leave(room) {
    this.leaveCalls.push(room);
  }
}

class RouterStub extends Service {
  @tracked currentURL = "/latest";
  @tracked currentRoute = null;

  transitionTo() {}
}

module("Integration | Component | voice/call-widget", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.currentUser = logIn(this.owner);

    this.owner.unregister("service:voice-rooms");
    this.owner.register("service:voice-rooms", VoiceRoomsStub);
    this.owner.unregister("service:voice-webrtc");
    this.owner.register("service:voice-webrtc", VoiceWebrtcStub);
    this.owner.unregister("service:router");
    this.owner.register("service:router", RouterStub);

    this.voiceRooms = this.owner.lookup("service:voice-rooms");
    this.voiceWebrtc = this.owner.lookup("service:voice-webrtc");
    this.voiceWebrtc.voiceRooms = this.voiceRooms;

    this.voiceRooms.rooms = [
      {
        id: 1,
        slug: "test-room",
        name: "Test Room",
        video_enabled: true,
        // Makes the chat button eligible, so the extra-minimized test's exact
        // control count guards against it leaking into that mode.
        chat_available: true,
        active_participants: [
          {
            id: this.currentUser.id,
            username: this.currentUser.username,
            avatar_template: "/letter_avatar_proxy/v4/letter/a/{size}.png",
          },
        ],
      },
    ];
  });

  test("keeps video watching and participant tiles live in widget mode", async function (assert) {
    this.set("renderWidget", true);
    await render(
      <template>
        {{#if this.renderWidget}}
          <VoiceCallWidget />
        {{/if}}
      </template>
    );

    assert.deepEqual(
      this.voiceWebrtc.watchingCalls.at(-1),
      { roomId: 1, watching: true, options: {} },
      "marks the room watched while the widget is visible"
    );

    this.voiceWebrtc.videoStreams.set("1:2", { id: "bob-video" });
    this.voiceRooms.setParticipants(1, [
      ...this.voiceRooms.roomById(1).active_participants,
      {
        id: 2,
        username: "bob",
        avatar_template: "/letter_avatar_proxy/v4/letter/b/{size}.png",
        is_video_on: true,
      },
    ]);
    await settled();

    assert
      .dom(".voice-call-widget .voice-video-tile[data-user-id='2']")
      .exists("adds a participant tile while the widget is docked");
    assert
      .dom(
        ".voice-call-widget .voice-video-tile[data-user-id='2'] video.voice-video-tile__video"
      )
      .exists("renders the live remote video element in the widget");

    this.voiceRooms.setParticipants(1, [
      this.voiceRooms.roomById(1).active_participants[0],
    ]);
    await settled();

    assert
      .dom(".voice-call-widget .voice-video-tile[data-user-id='2']")
      .doesNotExist("removes the participant tile while the widget is docked");

    this.set("renderWidget", false);
    await settled();

    assert.deepEqual(
      this.voiceWebrtc.watchingCalls.at(-1),
      { roomId: 1, watching: false, options: { keepVideo: true } },
      "clears the widget watch state when the widget is removed"
    );
  });

  test("hides on the room's own page even when the URL carries extra query params", async function (assert) {
    const router = this.owner.lookup("service:router");

    await render(<template><VoiceCallWidget /></template>);
    assert.dom(".voice-call-widget").exists("shows while docked elsewhere");

    router.currentRoute = {
      name: "voice-room",
      params: { slug: "test-room" },
      queryParams: { chat: "true" },
    };
    await settled();

    assert
      .dom(".voice-call-widget")
      .doesNotExist("hides on the room's own page, regardless of query params");

    router.currentRoute = { name: "discovery.latest", params: {} };
    await settled();

    assert
      .dom(".voice-call-widget")
      .exists("shows again once navigated away from the room page");
  });

  test("stays hidden while the user has hidden the call widget", async function (assert) {
    await render(<template><VoiceCallWidget /></template>);
    assert.dom(".voice-call-widget").exists("shows by default");

    this.voiceWebrtc.callWidgetHidden = true;
    await settled();

    assert
      .dom(".voice-call-widget")
      .doesNotExist("hides while the preference is on");

    this.voiceWebrtc.callWidgetHidden = false;
    await settled();

    assert
      .dom(".voice-call-widget")
      .exists("shows again once the preference is turned off");
  });

  test("collapses a crowd into a +N overflow tile", async function (assert) {
    // A small persisted size makes the solver's slot count independent of the
    // test viewport.
    this.owner.lookup("service:key-value-store").set({
      key: "voice-widget-size",
      value: JSON.stringify({ width: 320, height: 220 }),
    });

    const fakes = Array.from({ length: 11 }, (_, i) => {
      const letter = String.fromCharCode(97 + i);
      return {
        id: 100 + i,
        username: `user_${letter}`,
        avatar_template: `/letter_avatar_proxy/v4/letter/${letter}/{size}.png`,
      };
    });
    this.voiceRooms.setParticipants(1, [
      ...this.voiceRooms.roomById(1).active_participants,
      ...fakes,
    ]);

    await render(<template><VoiceCallWidget /></template>);
    await waitUntil(() =>
      document.querySelector(".voice-call-widget__overflow-tile")
    );

    const tileCount = document.querySelectorAll(
      ".voice-call-widget .voice-video-tile"
    ).length;
    const hidden = parseInt(
      document
        .querySelector(".voice-call-widget__overflow-count")
        .textContent.trim()
        .replace("+", ""),
      10
    );

    assert.true(tileCount < 12, "hides part of the crowd");
    assert.true(hidden >= 2, "the overflow tile absorbs at least two people");
    assert.strictEqual(
      tileCount + hidden,
      12,
      "every participant is either a tile or counted"
    );
    assert
      .dom(".voice-call-widget__overflow-avatars img")
      .exists("previews hidden participants' avatars");
  });

  test("keeps camera publishers out of the overflow", async function (assert) {
    this.owner.lookup("service:key-value-store").set({
      key: "voice-widget-size",
      value: JSON.stringify({ width: 320, height: 220 }),
    });

    const fakes = Array.from({ length: 9 }, (_, i) => {
      const letter = String.fromCharCode(97 + i);
      return {
        id: 100 + i,
        username: `user_${letter}`,
        avatar_template: `/letter_avatar_proxy/v4/letter/${letter}/{size}.png`,
      };
    });
    this.voiceWebrtc.videoStreams.set("1:300", { id: "zed-video" });
    this.voiceRooms.setParticipants(1, [
      ...this.voiceRooms.roomById(1).active_participants,
      ...fakes,
      {
        id: 300,
        username: "zed",
        avatar_template: "/letter_avatar_proxy/v4/letter/z/{size}.png",
        is_video_on: true,
      },
    ]);

    await render(<template><VoiceCallWidget /></template>);
    await waitUntil(() =>
      document.querySelector(".voice-call-widget__overflow-tile")
    );

    assert
      .dom(
        ".voice-call-widget .voice-video-tile[data-user-id='300'] video.voice-video-tile__video"
      )
      .exists("the camera publisher is promoted out of the overflow tail");
    assert
      .dom(".voice-call-widget .voice-video-tile[data-user-id='100']")
      .doesNotExist("an avatar-only participant yields the slot");
  });

  test("shows everyone without an overflow tile when they fit", async function (assert) {
    const fakes = Array.from({ length: 3 }, (_, i) => {
      const letter = String.fromCharCode(97 + i);
      return {
        id: 100 + i,
        username: `user_${letter}`,
        avatar_template: `/letter_avatar_proxy/v4/letter/${letter}/{size}.png`,
      };
    });
    this.voiceRooms.setParticipants(1, [
      ...this.voiceRooms.roomById(1).active_participants,
      ...fakes,
    ]);

    await render(<template><VoiceCallWidget /></template>);
    await waitUntil(
      () =>
        document.querySelectorAll(".voice-call-widget .voice-video-tile")
          .length === 4
    );

    assert
      .dom(".voice-call-widget .voice-video-tile")
      .exists({ count: 4 }, "renders a tile per participant");
    assert
      .dom(".voice-call-widget__overflow-tile")
      .doesNotExist("no overflow tile when everyone fits");
  });

  test("resizing below the widget threshold enters extra minimized mode", async function (assert) {
    await render(<template><VoiceCallWidget /></template>);

    const widget = document.querySelector(".voice-call-widget");
    widget.getBoundingClientRect = () => ({
      left: 100,
      top: 100,
      right: 500,
      bottom: 340,
      width: 400,
      height: 240,
    });

    await triggerEvent(".voice-call-widget__resize.--se", "mousedown", {
      button: 0,
      clientX: 500,
      clientY: 340,
    });
    await triggerEvent(window, "mousemove", {
      clientX: 250,
      clientY: 220,
    });
    await triggerEvent(window, "mouseup");

    assert
      .dom(".voice-call-widget")
      .hasClass(
        "--extra-minimized",
        "marks the widget as extra minimized after crossing the resize threshold"
      );
    assert
      .dom(".voice-call-widget__tiles")
      .doesNotExist("hides participant tiles in extra minimized mode");
    assert
      .dom(".voice-call-widget__controls button")
      .exists({ count: 2 }, "only renders expand and leave controls");
    assert.false(
      /inset-inline-start|inset-block-start/.test(
        document.querySelector(".voice-call-widget").getAttribute("style") ?? ""
      ),
      "keeps the extra minimized widget pinned to the bottom-right corner"
    );

    await click(".voice-call-widget__expand");

    assert
      .dom(".voice-call-widget")
      .doesNotHaveClass(
        "--extra-minimized",
        "expands back to the default widget dimensions"
      );
    assert
      .dom(".voice-call-widget__tiles")
      .exists("restores the default widget content");
    assert.false(
      /inset-inline-start|inset-block-start/.test(
        document.querySelector(".voice-call-widget").getAttribute("style") ?? ""
      ),
      "expands from the bottom-right corner instead of the old resize position"
    );
  });
});
