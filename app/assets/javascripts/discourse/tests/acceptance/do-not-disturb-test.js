import {
  acceptance,
  exists,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Do not disturb", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/do-not-disturb.json", () => {
      let now = new Date();
      now.setHours(now.getHours() + 1);
      return helper.response({ ends_at: now });
    });
    server.delete("/do-not-disturb.json", () =>
      helper.response({ success: true })
    );
  });

  test("when turned off, it is turned on from modal", async function (assert) {
    updateCurrentUser({ do_not_disturb_until: null });

    await visit("/");
    await click(".header-dropdown-toggle.current-user");
    await click(".menu-links-row .user-preferences-link");

    await click(".do-not-disturb");

    assert.ok(exists(".do-not-disturb-modal"), "modal to choose time appears");

    let tiles = queryAll(".do-not-disturb-tile");
    assert.ok(tiles.length === 4, "There are 4 duration choices");

    await click(tiles[0]);

    assert.ok(query(".do-not-disturb-modal.hidden"), "modal is hidden");

    assert.ok(
      exists(".header-dropdown-toggle .do-not-disturb-background .d-icon-moon"),
      "moon icon is present in header"
    );
  });

  test("Can be invoked via keyboard", async function (assert) {
    updateCurrentUser({ do_not_disturb_until: null });

    await visit("/");
    await click(".header-dropdown-toggle.current-user");
    await click(".menu-links-row .user-preferences-link");
    await click(".do-not-disturb");

    assert.ok(exists(".do-not-disturb-modal"), "DND modal is displayed");

    assert.strictEqual(
      queryAll(".do-not-disturb-tile").length,
      4,
      "There are 4 duration choices"
    );

    await triggerKeyEvent(".do-not-disturb-tile:nth-child(1)", "keydown", 13);

    assert.ok(
      query(".do-not-disturb-modal.hidden"),
      "DND modal is hidden after making a choice"
    );

    assert.ok(
      exists(".header-dropdown-toggle .do-not-disturb-background .d-icon-moon"),
      "moon icon is shown in header avatar"
    );
  });

  test("when turned on, it can be turned off", async function (assert) {
    let now = new Date();
    now.setHours(now.getHours() + 1);
    updateCurrentUser({ do_not_disturb_until: now });

    await visit("/");
    await click(".header-dropdown-toggle.current-user");
    await click(".menu-links-row .user-preferences-link");
    assert.strictEqual(
      query(".do-not-disturb .relative-date").textContent,
      "1h"
    );

    await click(".do-not-disturb");

    assert.ok(
      !exists(".do-not-disturb-background"),
      "The active moon icons are removed"
    );
  });
});
