import { getOwner } from "@ember/owner";
import { click, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const PARTICIPANT_ROW = "[data-link-name='voice-participant-1-2']";
const MENU = ".fk-d-menu[data-identifier='voice-participant-menu']";

acceptance("Voice participant context menu", function (needs) {
  needs.user();
  needs.settings({ voice_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/voice/rooms.json", () =>
      helper.response({
        rooms: [
          {
            id: 1,
            name: "Conf room",
            slug: "conf-room",
            public: true,
            room_type: "open",
            active_participants: [
              {
                id: 2,
                username: "jane",
                name: "Jane",
                avatar_template: "/letter_avatar_proxy/v4/letter/j/{size}.png",
              },
            ],
          },
        ],
        can_create_room: false,
      })
    );
  });

  test("offers no menu for a room the user is not connected to", async function (assert) {
    await visit("/latest");

    assert.dom(PARTICIPANT_ROW).exists("the participant row still renders");
    assert
      .dom(`${PARTICIPANT_ROW} .sidebar-section-hover-button`)
      .doesNotExist("the hover menu button is not rendered");

    await triggerEvent(PARTICIPANT_ROW, "contextmenu");

    assert.dom(MENU).doesNotExist("right-click does not open the menu either");
  });

  test("offers the menu for a room the user is connected to", async function (assert) {
    const voiceWebrtc = getOwner(this).lookup("service:voice-webrtc");
    voiceWebrtc.connectionStateFor = () => "connected";

    await visit("/latest");

    await click(`${PARTICIPANT_ROW} .sidebar-section-hover-button`);

    assert.dom(MENU).exists("the participant menu opens");
    assert
      .dom(".voice-participant-sidebar-context-menu__volume-slider")
      .exists("audio controls are available");
    assert
      .dom(".voice-participant-sidebar-context-menu__spotlight-btn")
      .doesNotExist(
        "page-only spotlight controls are not shown in the sidebar"
      );
  });
});
