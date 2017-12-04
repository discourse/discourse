import { acceptance } from "helpers/qunit-helpers";
import { displayPollBuilderButton } from "discourse/plugins/poll/helpers/display-poll-builder-button";
import { replaceCurrentUser } from "discourse/plugins/poll/helpers/replace-current-user";

acceptance("Poll Builder - allow staff", {
  loggedIn: true,
  settings: {
    poll_enabled: true,
    poll_allow_staff_to_create: true,
    poll_minimum_trust_level_to_create: 4
  }
});

test("staff", (assert) => {
  replaceCurrentUser({ staff: true, trust_level: 3 });

  displayPollBuilderButton();

  andThen(() => {
    assert.ok(exists("button[title='Build Poll']"), "it shows the builder button");
  });
});
