import { acceptance } from "helpers/qunit-helpers";
import { displayPollBuilderButton } from "discourse/plugins/poll/helpers/display-poll-builder-button";
import { setCurrentUserWithTrustLevel } from "discourse/plugins/poll/helpers/set-current-user-with-trust-level";

acceptance("Poll Builder - disabled", {
  loggedIn: true,
  settings: {
    poll_enabled: false,
    poll_minimum_trust_level_to_create: 2
  }
});

test("sufficient trust level", (assert) => {
  setCurrentUserWithTrustLevel(3);

  displayPollBuilderButton();

  andThen(() => {
    assert.ok(!exists("button[title='Build Poll']"), "it hides the builder button");
  });
});

test("insufficient trust level", (assert) => {
  setCurrentUserWithTrustLevel(1);

  displayPollBuilderButton();

  andThen(() => {
    assert.ok(!exists("button[title='Build Poll']"), "it hides the builder button");
  });
});
