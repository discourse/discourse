import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("User Notes", function (needs) {
  needs.user();
  needs.settings({ user_notes_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/user_notes", () => {
      return helper.response(200, {
        extras: { username: "eviltrout" },
        user_notes: [],
      });
    });

    server.post("/user_notes", () => {
      return helper.response(200, {
        user_note: {
          id: "6d945d25740e9801920e54c71c516c7b",
          user_id: 1,
          raw: "Helpful user",
          created_by: {
            id: 2,
            username: "sam",
            name: null,
            avatar_template:
              "/letter_avatar_proxy/v4/letter/s/ac8455/{size}.png",
          },
          created_at: "2022-11-16T22:00:00.000Z",
          can_delete: true,
          post_id: null,
          post_url: "",
          post_title: null,
        },
      });
    });
  });

  test("creates note from user's profile", async function (assert) {
    await visit("/admin/users/1/eviltrout");

    const modalClass = ".user-notes-modal";
    assert
      .dom(".user-controls .show-user-notes-btn")
      .hasText(i18n("user_notes.title"));
    assert.dom(modalClass).doesNotExist();

    await click(".user-controls .show-user-notes-btn");

    assert.dom(modalClass).exists();

    await fillIn(`${modalClass} textarea`, "Helpful user");

    assert.dom(`${modalClass} .btn-primary`).isEnabled();

    await click(`${modalClass} .btn-primary`);
    await click(`${modalClass} .modal-close`);

    assert
      .dom(".user-controls .show-user-notes-btn")
      .hasText(i18n("user_notes.show", { count: 1 }));
  });
});
