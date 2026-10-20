import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Live | Admin rooms", function (needs) {
  needs.user({ admin: true });
  needs.settings({ live_enabled: true, chat_enabled: false });

  let rooms = [];

  needs.hooks.beforeEach(() => {
    rooms = [];
  });

  needs.pretender((server, helper) => {
    server.get("/admin/plugins/live.json", () =>
      helper.response({
        id: "live",
        name: "live",
        enabled: true,
        has_settings: true,
        humanized_name: "Live",
        admin_route: {
          label: "live.admin.title",
          location: "live",
          use_new_show_route: true,
        },
      })
    );

    server.get("/live/rooms.json", () => helper.response({ rooms: [] }));

    server.get("/admin/plugins/live/rooms.json", () =>
      helper.response({ rooms })
    );

    server.post("/admin/plugins/live/rooms.json", (request) => {
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
    await visit("/admin/plugins/live/live-rooms");
    await click(".live-admin__create-btn");
    await fillIn("input[name='name']", "Lounge");
    await click(".form-kit__button.btn-primary");

    assert
      .dom(".live-rooms__name-link")
      .hasAttribute("href", "/admin/plugins/live/live-rooms/42");
  });
});
