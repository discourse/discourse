import {
  acceptance,
  exists,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance(
  "Opening the hamburger menu with some reviewables",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      server.get("/review/count.json", () => helper.response({ count: 3 }));
    });
    needs.settings({
      navigation_menu: "legacy",
    });
    test("As a staff member", async function (assert) {
      updateCurrentUser({ moderator: true, admin: false });

      await visit("/");
      await click(".hamburger-dropdown");

      assert.strictEqual(
        query(".review .badge-notification.reviewables").innerText,
        "3"
      );
    });
  }
);

acceptance("Hamburger Menu accessibility", function (needs) {
  needs.settings({
    navigation_menu: "legacy",
  });
  test("Escape key closes hamburger menu", async function (assert) {
    await visit("/");
    await click("#toggle-hamburger-menu");
    await triggerKeyEvent(".hamburger-panel", "keydown", "Escape");
    assert.ok(!exists(".hamburger-panel"), "Esc closes the hamburger panel");
  });
});
