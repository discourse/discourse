import { exists } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { displayPollBuilderButton } from "discourse/plugins/poll/helpers/display-poll-builder-button";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";

acceptance("Poll Builder - polls are enabled", function (needs) {
  needs.user();
  needs.settings({
    poll_enabled: true,
    poll_minimum_trust_level_to_create: 1,
  });
  needs.hooks.beforeEach(() => clearPopupMenuOptionsCallback());

  test("regular user - sufficient trust level", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 1 });

    await displayPollBuilderButton();

    assert.ok(
      exists(".select-kit-row[title='Build Poll']"),
      "it shows the builder button"
    );
  });

  test("regular user - insufficient trust level", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 0 });

    await displayPollBuilderButton();

    assert.ok(
      !exists(".select-kit-row[title='Build Poll']"),
      "it hides the builder button"
    );
  });

  test("staff - with insufficient trust level", async function (assert) {
    updateCurrentUser({ moderator: true, trust_level: 0 });

    await displayPollBuilderButton();

    assert.ok(
      exists(".select-kit-row[title='Build Poll']"),
      "it shows the builder button"
    );
  });

  test("poll preview", async function (assert) {
    await displayPollBuilderButton();

    const popupMenu = selectKit(".toolbar-popup-menu-options");
    await popupMenu.selectRowByValue("showPollBuilder");

    await fillIn(".poll-textarea textarea", "First option\nSecond option");

    assert.equal(
      queryAll(".d-editor-preview li:first-child").text(),
      "First option"
    );
    assert.equal(
      queryAll(".d-editor-preview li:last-child").text(),
      "Second option"
    );
  });
});
