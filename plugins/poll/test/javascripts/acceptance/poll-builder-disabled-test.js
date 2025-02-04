import { test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { displayPollBuilderButton } from "discourse/plugins/poll/helpers/display-poll-builder-button";

acceptance("Poll Builder - polls are disabled", function (needs) {
  needs.user();
  needs.settings({
    poll_enabled: false,
    poll_create_allowed_groups: AUTO_GROUPS.trust_level_2,
  });

  test("regular user - sufficient permissions", async function (assert) {
    updateCurrentUser({
      moderator: false,
      admin: false,
      trust_level: 3,
      can_create_poll: true,
    });

    await displayPollBuilderButton();

    assert
      .dom(".select-kit-row[data-value='showPollBuilder']")
      .doesNotExist("it hides the builder button");
  });

  test("regular user - insufficient permissions", async function (assert) {
    updateCurrentUser({
      moderator: false,
      admin: false,
      trust_level: 1,
      can_create_poll: false,
    });

    await displayPollBuilderButton();

    assert
      .dom(".select-kit-row[data-value='showPollBuilder']")
      .doesNotExist("it hides the builder button");
  });

  test("staff", async function (assert) {
    updateCurrentUser({ moderator: true });

    await displayPollBuilderButton();

    assert
      .dom(".select-kit-row[data-value='showPollBuilder']")
      .doesNotExist("it hides the builder button");
  });
});
