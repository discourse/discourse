import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import DoNotDisturb from "discourse/lib/do-not-disturb";
import {
  acceptance,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Do not disturb", function (needs) {
  needs.pretender((server, helper) => {
    server.post("/do-not-disturb.json", () => {
      const now = new Date();
      now.setHours(now.getHours() + 1);
      return helper.response({ ends_at: now });
    });
    server.delete("/do-not-disturb.json", () =>
      helper.response({ success: true })
    );
  });
  needs.user();

  test("when turned off, it is turned on from modal", async function (assert) {
    updateCurrentUser({ do_not_disturb_until: null });

    await visit("/");
    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");
    await click("#quick-access-profile .do-not-disturb .btn");

    assert.dom(".do-not-disturb-modal").exists("modal to choose time appears");

    let tiles = queryAll(".do-not-disturb-tile");
    assert.strictEqual(tiles.length, 4, "There are 4 duration choices");

    await click(tiles[0]);

    assert.dom(".d-modal").doesNotExist("modal is hidden");

    assert
      .dom(
        ".header-dropdown-toggle .do-not-disturb-background .d-icon-discourse-dnd"
      )
      .exists("dnd icon is present in header");
  });

  test("Can be invoked via keyboard", async function (assert) {
    updateCurrentUser({ do_not_disturb_until: null });

    await visit("/");
    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");
    await click("#quick-access-profile .do-not-disturb .btn");

    assert.dom(".do-not-disturb-modal").exists("DND modal is displayed");
    assert
      .dom(".do-not-disturb-tile")
      .exists({ count: 4 }, "there are 4 duration choices");

    await triggerKeyEvent(
      ".do-not-disturb-tile:nth-child(1)",
      "keydown",
      "Enter"
    );

    assert
      .dom(".d-modal")
      .doesNotExist("DND modal is hidden after making a choice");

    assert
      .dom(
        ".header-dropdown-toggle .do-not-disturb-background .d-icon-discourse-dnd"
      )
      .exists("dnd icon is shown in header avatar");
  });

  test("when turned on, it can be turned off", async function (assert) {
    const now = new Date();
    now.setHours(now.getHours() + 1);
    updateCurrentUser({ do_not_disturb_until: now });

    await visit("/");

    assert
      .dom(".do-not-disturb-background")
      .exists("The active dnd icon is shown");

    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");
    assert.strictEqual(
      query(".do-not-disturb .relative-date").textContent.trim(),
      "1h",
      "the Do Not Disturb button shows how much time is left for DND mode"
    );
    assert
      .dom(".do-not-disturb .d-icon-toggle-on")
      .exists("the Do Not Disturb button has the toggle-on icon");

    await click("#quick-access-profile .do-not-disturb .btn");

    assert
      .dom(".do-not-disturb-background")
      .doesNotExist("The active dnd icon is removed");
    assert
      .dom(".do-not-disturb .relative-date")
      .doesNotExist(
        "the text showing how much time is left for DND mode is gone"
      );
    assert
      .dom(".do-not-disturb .d-icon-toggle-off")
      .exists("the Do Not Disturb button has the toggle-off icon");
  });

  test("user menu gets closed when the DnD modal is opened", async function (assert) {
    this.siteSettings.enable_user_status = true;

    await visit("/");
    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");
    await click("#quick-access-profile .do-not-disturb .btn");

    assert.dom(".user-menu").doesNotExist();
  });

  test("doesn't show the end date for eternal DnD", async function (assert) {
    updateCurrentUser({ do_not_disturb_until: DoNotDisturb.forever });

    await visit("/");
    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");

    assert.dom(".do-not-disturb .relative-date").doesNotExist();
  });
});
