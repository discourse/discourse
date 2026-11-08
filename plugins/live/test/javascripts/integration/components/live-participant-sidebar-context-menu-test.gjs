import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import LiveParticipantSidebarContextMenu from "discourse/plugins/live/discourse/components/live-participant-sidebar-context-menu";

class LiveWebrtcStub extends Service {
  getParticipantVolume() {
    return 1;
  }

  isParticipantMuted() {
    return false;
  }
}

module(
  "Integration | Component | LiveParticipantSidebarContextMenu",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      logIn(this.owner);
      this.owner.unregister("service:live-webrtc");
      this.owner.register("service:live-webrtc", LiveWebrtcStub);

      this.selectedParticipantId = null;
      this.closed = false;
      this.menuData = {
        room: { id: 1, room_type: "open" },
        participant: { id: 2, username: "bob" },
        isCurrentUser: false,
        onSpotlight: (participantId) => {
          this.selectedParticipantId = participantId;
        },
      };
      this.closeMenu = () => {
        this.closed = true;
      };
    });

    test("kicks a bot without an expulsion dialog", async function (assert) {
      this.menuData.participant = {
        id: -2,
        username: "livekit_agent_bot",
        external_agent: true,
      };
      this.menuData.canManageRoom = true;
      let kicked = false;
      pretender.delete("/live/rooms/1/kick", (request) => {
        kicked = true;
        assert.strictEqual(
          request.requestBody,
          "user_id=-2",
          "sends only the bot ID"
        );
        return response(204);
      });
      await render(
        <template>
          <LiveParticipantSidebarContextMenu
            @close={{this.closeMenu}}
            @data={{this.menuData}}
          />
        </template>
      );

      await click(".live-participant-sidebar-context-menu__kick-btn");

      assert.true(kicked);
      assert.true(this.closed);
      assert.dom(".d-modal").doesNotExist();
    });

    test("promotes a listener to a session-only speaker", async function (assert) {
      this.menuData.room = { id: 1, room_type: "stage" };
      this.menuData.canManageRoom = true;
      let body;
      pretender.post("/live/rooms/1/memberships", (request) => {
        body = request.requestBody;
        return response({ membership: {} });
      });
      await render(
        <template>
          <LiveParticipantSidebarContextMenu
            @close={{this.closeMenu}}
            @data={{this.menuData}}
          />
        </template>
      );

      await click(".live-participant-sidebar-context-menu__promote-btn");

      assert.true(body.includes("role=speaker"), "asks for the speaker role");
      assert.true(
        body.includes("session_only=true"),
        "limits the grant to the session"
      );
    });

    test("invites a listener to speak and can withdraw the invitation", async function (assert) {
      this.menuData.room = { id: 1, room_type: "stage" };
      this.menuData.canManageRoom = true;
      const calls = [];
      pretender.post("/live/rooms/1/speak_invitation", (request) => {
        calls.push(["POST", request.requestBody]);
        return response(204);
      });
      await render(
        <template>
          <LiveParticipantSidebarContextMenu
            @close={{this.closeMenu}}
            @data={{this.menuData}}
          />
        </template>
      );

      assert
        .dom(".live-participant-sidebar-context-menu__withdraw-invitation-btn")
        .doesNotExist();
      await click(
        ".live-participant-sidebar-context-menu__invite-to-speak-btn"
      );

      assert.deepEqual(calls, [["POST", "user_id=2"]]);
    });

    test("offers to withdraw a pending invitation instead of inviting again", async function (assert) {
      this.menuData.room = { id: 1, room_type: "stage" };
      this.menuData.canManageRoom = true;
      this.menuData.participant = {
        id: 2,
        username: "bob",
        speak_invited_at: 123,
      };
      let withdrawn = false;
      pretender.delete("/live/rooms/1/speak_invitation", () => {
        withdrawn = true;
        return response(204);
      });
      await render(
        <template>
          <LiveParticipantSidebarContextMenu
            @close={{this.closeMenu}}
            @data={{this.menuData}}
          />
        </template>
      );

      assert
        .dom(".live-participant-sidebar-context-menu__invite-to-speak-btn")
        .doesNotExist();
      await click(
        ".live-participant-sidebar-context-menu__withdraw-invitation-btn"
      );

      assert.true(withdrawn);
    });

    test("does not offer invitations to speakers or in open rooms", async function (assert) {
      this.menuData.canManageRoom = true;
      await render(
        <template>
          <LiveParticipantSidebarContextMenu
            @close={{this.closeMenu}}
            @data={{this.menuData}}
          />
        </template>
      );

      assert
        .dom(".live-participant-sidebar-context-menu__invite-to-speak-btn")
        .doesNotExist();
    });

    test("spotlights the participant for the viewer", async function (assert) {
      await render(
        <template>
          <LiveParticipantSidebarContextMenu
            @close={{this.closeMenu}}
            @data={{this.menuData}}
          />
        </template>
      );

      assert
        .dom(".live-participant-sidebar-context-menu__spotlight-btn")
        .hasText("Spotlight for me", "offers the local spotlight action");

      await click(".live-participant-sidebar-context-menu__spotlight-btn");

      assert.strictEqual(
        this.selectedParticipantId,
        2,
        "selects the menu's participant"
      );
      assert.true(this.closed, "closes the participant menu");
    });

    test("shows when the participant is already spotlighted", async function (assert) {
      this.menuData.isSpotlighted = true;

      await render(
        <template>
          <LiveParticipantSidebarContextMenu
            @close={{this.closeMenu}}
            @data={{this.menuData}}
          />
        </template>
      );

      assert
        .dom(".live-participant-sidebar-context-menu__spotlight-btn")
        .hasText("Remove from spotlight", "offers to remove the spotlight")
        .hasAttribute("aria-pressed", "true", "exposes the active state");
    });
  }
);
