import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Voice anon sidebar", function (needs) {
  needs.settings({ voice_enabled: true });
  needs.site({ voice_public_access: true });

  needs.pretender((server, helper) => {
    server.get("/voice/rooms.json", () =>
      helper.response({
        rooms: [
          {
            id: 1,
            name: "Public room",
            slug: "public-room",
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

  test("renders public rooms for anonymous visitors", async function (assert) {
    await visit("/latest");

    assert
      .dom(".sidebar-section[data-section-name='voice-rooms']")
      .exists("the rooms section is rendered");
    assert
      .dom("[data-link-name='voice-room-1']")
      .hasText("Public room", "the public room link is rendered");
    assert
      .dom("[data-link-name='voice-participant-1-2']")
      .hasText("jane", "public room participants are rendered");

    const sectionNames = [
      ...document.querySelectorAll(
        ".sidebar-sections-anonymous > .sidebar-section"
      ),
    ].map((section) => section.dataset.sectionName);

    assert.true(
      sectionNames.includes("categories"),
      "the standard navigation sections are rendered"
    );
    assert.true(
      sectionNames.indexOf("voice-rooms") > sectionNames.indexOf("categories"),
      "rooms render after the standard navigation sections, as they do for logged-in users"
    );
  });
});
