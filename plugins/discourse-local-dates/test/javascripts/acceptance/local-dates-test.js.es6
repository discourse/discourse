import { acceptance } from "helpers/qunit-helpers";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";

acceptance("Local Dates", {
  loggedIn: true,
  settings: { discourse_local_dates_enabled: true },
  beforeEach() {
    clearPopupMenuOptionsCallback();
  },
  afterEach() {
    sinon.restore();
  }
});

test("at removal", assert => {
  let now = moment("2018-06-20").valueOf();
  let timezone = moment.tz.guess();

  sinon.useFakeTimers(now);

  let html = `<span data-timezones="${timezone}" data-timezone="${timezone}" class="discourse-local-date past cooked-date" data-date="DATE" data-format="L LTS" data-time="14:42:26"></span>`;

  let yesterday = $(html.replace("DATE", "2018-06-19"));
  yesterday.applyLocalDates();

  assert.equal(yesterday.text(), "Yesterday 2:42 PM");

  let today = $(html.replace("DATE", "2018-06-20"));
  today.applyLocalDates();

  assert.equal(today.text(), "Today 2:42 PM");

  let tomorrow = $(html.replace("DATE", "2018-06-21"));
  tomorrow.applyLocalDates();

  assert.equal(tomorrow.text(), "Tomorrow 2:42 PM");
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
