import { exists } from "discourse/tests/helpers/qunit-helpers";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { displayPollBuilderButton } from "discourse/plugins/poll/helpers/display-poll-builder-button";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";

acceptance("Poll Builder - polls are disabled", function (needs) {
  needs.user();
  needs.settings({
    poll_enabled: false,
    poll_minimum_trust_level_to_create: 2,
  });
  needs.hooks.beforeEach(() => clearPopupMenuOptionsCallback());

  test("regular user - sufficient trust level", async (assert) => {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 3 });

    await displayPollBuilderButton();

    assert.ok(
      !exists(".select-kit-row[title='Build Poll']"),
      "it hides the builder button"
    );
  });

  test("regular user - insufficient trust level", async (assert) => {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 1 });

    await displayPollBuilderButton();

    assert.ok(
      !exists(".select-kit-row[title='Build Poll']"),
      "it hides the builder button"
    );
  });

  test("staff", async (assert) => {
    updateCurrentUser({ moderator: true });

    await displayPollBuilderButton();

    assert.ok(
      !exists(".select-kit-row[title='Build Poll']"),
      "it hides the builder button"
    );
  });
});
