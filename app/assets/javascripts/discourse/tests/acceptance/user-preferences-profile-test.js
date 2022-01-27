import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance(
  "User profile preferences without default calendar set",
  function (needs) {
    needs.user({ default_calendar: "none_selected" });

    test("default calendar option is not visible", async function (assert) {
      await visit("/u/eviltrout/preferences/profile");

      assert.ok(
        !exists("#user-default-calendar"),
        "option to change default calendar is hidden"
      );
    });
  }
);

acceptance(
  "User profile preferences with default calendar set",
  function (needs) {
    needs.user({ default_calendar: "google" });

    test("default calendar can be changed", async function (assert) {
      await visit("/u/eviltrout/preferences/profile");

      assert.ok(
        exists("#user-default-calendar"),
        "option to change default calendar"
      );
    });
  }
);
