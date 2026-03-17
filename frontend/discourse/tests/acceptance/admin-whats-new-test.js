import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const RELEASE_NOTES_URL =
  "https://meta.discourse.org/tags/c/announcements/67/release-notes";

acceptance("Admin - What's New", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/whats-new.json", () => {
      return helper.response(500, {
        errors: ["Internal Server Error"],
      });
    });
  });

  test("it shows a feed error when loading fails", async function (assert) {
    await visit("/admin/whats-new");

    assert.dom(".admin-config-area-empty-list").exists();
    assert
      .dom(`.admin-config-area-empty-list a[href="${RELEASE_NOTES_URL}"]`)
      .exists();
  });
});
