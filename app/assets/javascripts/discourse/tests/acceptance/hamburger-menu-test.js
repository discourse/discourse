import {
  acceptance,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance(
  "Opening the hamburger menu with some reviewables",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      server.get("/review/count.json", () => helper.response({ count: 3 }));
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
