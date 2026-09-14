import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import VoiceParticipantSidebarContextMenu from "discourse/plugins/voice/discourse/components/voice-participant-sidebar-context-menu";

class VoiceWebrtcStub extends Service {
  getParticipantVolume() {
    return 1;
  }

  isParticipantMuted() {
    return false;
  }
}

module(
  "Integration | Component | VoiceParticipantSidebarContextMenu",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      logIn(this.owner);
      this.owner.unregister("service:voice-webrtc");
      this.owner.register("service:voice-webrtc", VoiceWebrtcStub);

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
      pretender.delete("/voice/rooms/1/kick", (request) => {
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
          <VoiceParticipantSidebarContextMenu
            @data={{this.menuData}}
            @close={{this.closeMenu}}
          />
        </template>
      );

      await click(".voice-participant-sidebar-context-menu__kick-btn");

      assert.true(kicked);
      assert.true(this.closed);
      assert.dom(".d-modal").doesNotExist();
    });

    test("spotlights the participant for the viewer", async function (assert) {
      await render(
        <template>
          <VoiceParticipantSidebarContextMenu
            @data={{this.menuData}}
            @close={{this.closeMenu}}
          />
        </template>
      );

      assert
        .dom(".voice-participant-sidebar-context-menu__spotlight-btn")
        .hasText("Spotlight for me", "offers the local spotlight action");

      await click(".voice-participant-sidebar-context-menu__spotlight-btn");

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
          <VoiceParticipantSidebarContextMenu
            @data={{this.menuData}}
            @close={{this.closeMenu}}
          />
        </template>
      );

      assert
        .dom(".voice-participant-sidebar-context-menu__spotlight-btn")
        .hasText("Remove from spotlight", "offers to remove the spotlight")
        .hasAttribute("aria-pressed", "true", "exposes the active state");
    });
  }
);
