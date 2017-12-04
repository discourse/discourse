import { acceptance } from "helpers/qunit-helpers";
import { displayPollBuilderButton } from "discourse/plugins/poll/helpers/display-poll-builder-button";
import { replaceCurrentUser } from "discourse/plugins/poll/helpers/replace-current-user";

acceptance("Poll Builder - polls are enabled", {
  loggedIn: true,
  settings: {
    poll_enabled: true,
    poll_allow_staff_to_create: false,
    poll_minimum_trust_level_to_create: 1
  }
});

test("sufficient trust level", (assert) => {
  replaceCurrentUser({ admin: false, trust_level: 1 });

  displayPollBuilderButton();

  andThen(() => {
    assert.ok(exists("button[title='Build Poll']"), "it shows the builder button");
  });
});

test("insufficient trust level", (assert) => {
  replaceCurrentUser({ admin: false, trust_level: 0 });

  displayPollBuilderButton();

  andThen(() => {
    assert.ok(!exists("button[title='Build Poll']"), "it hides the builder button");
  });
});

test("staff with insufficient trust level", (assert) => {
  replaceCurrentUser({ admin: false, staff: true, trust_level: 0 });

  displayPollBuilderButton();

  andThen(() => {
    assert.ok(!exists("button[title='Build Poll']"), "it hides the builder button");
  });
});


test("admin with insufficient trust level", (assert) => {
  replaceCurrentUser({ admin: true, trust_level: 0 });

  displayPollBuilderButton();

  andThen(() => {
    assert.ok(exists("button[title='Build Poll']"), "it shows the builder button");
  });
});
