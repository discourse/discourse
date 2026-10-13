import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Voice | Admin rooms", function (needs) {
  needs.user({ admin: true });
  needs.settings({ voice_enabled: true, chat_enabled: false });

  let rooms = [];

  needs.hooks.beforeEach(() => {
    rooms = [];
  });

  needs.pretender((server, helper) => {
    server.get("/admin/plugins/voice.json", () =>
      helper.response({
        id: "voice",
        name: "voice",
        enabled: true,
        has_settings: true,
        humanized_name: "Voice",
        admin_route: {
          label: "voice.admin.title",
          location: "voice",
          use_new_show_route: true,
        },
      })
    );

    server.get("/voice/rooms.json", () => helper.response({ rooms: [] }));

    server.get("/admin/plugins/voice/rooms.json", () =>
      helper.response({ rooms })
    );

    server.post("/admin/plugins/voice/rooms.json", (request) => {
      const room = {
        ...JSON.parse(request.requestBody).room,
        id: 42,
        member_count: 0,
        created_at: new Date().toISOString(),
      };
      rooms.push(room);
      return helper.response(201, { room });
    });
  });

  test("room name links to the edit page after creating a room", async function (assert) {
    await visit("/admin/plugins/voice/voice-rooms");
    await click(".voice-admin__create-btn");
    await fillIn("input[name='name']", "Lounge");
    await click(".form-kit__button.btn-primary");

    assert
      .dom(".voice-rooms__name-link")
      .hasAttribute("href", "/admin/plugins/voice/voice-rooms/42");
  });
});
