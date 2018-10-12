import { acceptance } from "helpers/qunit-helpers";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";

acceptance("Local Dates", {
  loggedIn: true,
  settings: { discourse_local_dates_enabled: true },
  beforeEach() {
    clearPopupMenuOptionsCallback();
  }
});

test("local dates bbcode", async assert => {
  await visit("/");
  await click("#create-topic");

  await fillIn(
    ".d-editor-input",
    '[date=2017-10-23 time=01:30:00 format="LL" timezone="Asia/Calcutta" timezones="Europe/Paris|America/Los_Angeles"]'
  );

  assert.ok(
    exists(".d-editor-preview .discourse-local-date.past.cooked-date"),
    "it should contain the cooked output for date & time inputs"
  );

  await fillIn(
    ".d-editor-input",
    '[date=2017-10-23 format="LL" timezone="Asia/Calcutta" timezones="Europe/Paris|America/Los_Angeles"]'
  );

  assert.ok(
    exists(".d-editor-preview .discourse-local-date.past.cooked-date"),
    "it should contain the cooked output for date only input"
  );
});
