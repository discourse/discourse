import { getOwner } from "@ember/owner";
import { click, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const PARTICIPANT_ROW = "[data-link-name='live-participant-1-2']";
const MENU = ".fk-d-menu[data-identifier='live-participant-menu']";

acceptance("Live participant context menu", function (needs) {
  needs.user();
  needs.settings({ live_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/live/rooms.json", () =>
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
    const liveWebrtc = getOwner(this).lookup("service:live-webrtc");
    liveWebrtc.connectionStateFor = () => "connected";

    await visit("/latest");

    await click(`${PARTICIPANT_ROW} .sidebar-section-hover-button`);

    assert.dom(MENU).exists("the participant menu opens");
    assert
      .dom(".live-participant-sidebar-context-menu__volume-slider")
      .exists("audio controls are available");
    assert
      .dom(".live-participant-sidebar-context-menu__spotlight-btn")
      .doesNotExist(
        "page-only spotlight controls are not shown in the sidebar"
      );
  });
});
