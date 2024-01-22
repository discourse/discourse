import { test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import {
  acceptance,
  exists,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { displayPollBuilderButton } from "discourse/plugins/poll/helpers/display-poll-builder-button";

acceptance("Poll Builder - polls are disabled", function (needs) {
  needs.user();
  needs.settings({
    poll_enabled: false,
    poll_create_allowed_groups: AUTO_GROUPS.trust_level_2,
  });

  test("regular user - sufficient trust level", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 3 });

    await displayPollBuilderButton();

    assert.ok(
      !exists(".select-kit-row[data-value='showPollBuilder']"),
      "it hides the builder button"
    );
  });

  test("regular user - insufficient trust level", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 1 });

    await displayPollBuilderButton();

    assert.ok(
      !exists(".select-kit-row[data-value='showPollBuilder']"),
      "it hides the builder button"
    );
  });

  test("staff", async function (assert) {
    updateCurrentUser({ moderator: true });

    await displayPollBuilderButton();

    assert.ok(
      !exists(".select-kit-row[data-value='showPollBuilder']"),
      "it hides the builder button"
    );
  });
});
