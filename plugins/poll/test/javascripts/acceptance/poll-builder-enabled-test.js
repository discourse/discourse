import {
  acceptance,
  exists,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click } from "@ember/test-helpers";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";
import { displayPollBuilderButton } from "discourse/plugins/poll/helpers/display-poll-builder-button";
import { test } from "qunit";

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
      exists(".select-kit-row[data-value='showPollBuilder']"),
      "it shows the builder button"
    );

    await click(".select-kit-row[data-value='showPollBuilder']");
    assert.true(
      exists(".poll-type-value-regular.active"),
      "regular type is active"
    );
    await click(".poll-type-value-multiple");
    assert.true(
      exists(".poll-type-value-multiple.active"),
      "multiple type is active"
    );
    await click(".poll-type-value-regular");
    assert.true(
      exists(".poll-type-value-regular.active"),
      "regular type is active"
    );
  });

  test("regular user - insufficient trust level", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 0 });

    await displayPollBuilderButton();

    assert.ok(
      !exists(".select-kit-row[data-value='showPollBuilder]"),
      "it hides the builder button"
    );
  });

  test("staff - with insufficient trust level", async function (assert) {
    updateCurrentUser({ moderator: true, trust_level: 0 });

    await displayPollBuilderButton();

    assert.ok(
      exists(".select-kit-row[data-value='showPollBuilder']"),
      "it shows the builder button"
    );
  });
});
