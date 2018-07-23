import { acceptance, replaceCurrentUser } from "helpers/qunit-helpers";
acceptance("Topic - Edit timer", { loggedIn: true });

QUnit.test("default", async assert => {
  const timerType = selectKit(".select-kit.timer-type");
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-status-update button");

  assert.equal(futureDateInputSelector.header().title(), "Select a timeframe");
  assert.equal(futureDateInputSelector.header().value(), null);

  await click("#private-topic-timer");

  assert.equal(timerType.header().title(), "Remind Me");
  assert.equal(timerType.header().value(), "reminder");

  assert.equal(futureDateInputSelector.header().title(), "Select a timeframe");
  assert.equal(futureDateInputSelector.header().value(), null);
});

QUnit.test("autoclose - specific time", async assert => {
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-status-update button");

  await futureDateInputSelector.expandAwait();
  await futureDateInputSelector.selectRowByValueAwait("next_week");

  assert.equal(futureDateInputSelector.header().title(), "Next week");
  assert.equal(futureDateInputSelector.header().value(), "next_week");

  const regex = /will automatically close in/g;
  const html = find(".future-date-input .topic-status-info")
    .html()
    .trim();
  assert.ok(regex.test(html));
});

QUnit.test("autoclose", async assert => {
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-status-update button");

  await futureDateInputSelector.expandAwait();
  await futureDateInputSelector.selectRowByValueAwait("next_week");

  assert.equal(futureDateInputSelector.header().title(), "Next week");
  assert.equal(futureDateInputSelector.header().value(), "next_week");

  const regex1 = /will automatically close in/g;
  const html1 = find(".future-date-input .topic-status-info")
    .html()
    .trim();
  assert.ok(regex1.test(html1));

  await futureDateInputSelector.expandAwait();
  await futureDateInputSelector.selectRowByValueAwait("pick_date_and_time");

  await fillIn(".future-date-input .date-picker", "2099-11-24");

  assert.equal(futureDateInputSelector.header().title(), "Pick date and time");
  assert.equal(futureDateInputSelector.header().value(), "pick_date_and_time");

  const regex2 = /will automatically close in/g;
  const html2 = find(".future-date-input .topic-status-info")
    .html()
    .trim();
  assert.ok(regex2.test(html2));

  await futureDateInputSelector.expandAwait();
  await futureDateInputSelector.selectRowByValueAwait("set_based_on_last_post");

  await fillIn(".future-date-input input[type=number]", "2");

  assert.equal(
    futureDateInputSelector.header().title(),
    "Close based on last post"
  );
  assert.equal(
    futureDateInputSelector.header().value(),
    "set_based_on_last_post"
  );

  const regex3 = /This topic will close.*after the last reply/g;
  const html3 = find(".future-date-input .topic-status-info")
    .html()
    .trim();
  assert.ok(regex3.test(html3));
});

QUnit.test("close temporarily", async assert => {
  const timerType = selectKit(".select-kit.timer-type");
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-status-update button");

  await timerType.expandAwait();
  await timerType.selectRowByValueAwait("open");

  assert.equal(futureDateInputSelector.header().title(), "Select a timeframe");
  assert.equal(futureDateInputSelector.header().value(), null);

  await futureDateInputSelector.expandAwait();
  await futureDateInputSelector.selectRowByValueAwait("next_week");

  assert.equal(futureDateInputSelector.header().title(), "Next week");
  assert.equal(futureDateInputSelector.header().value(), "next_week");

  const regex1 = /will automatically open in/g;
  const html1 = find(".future-date-input .topic-status-info")
    .html()
    .trim();
  assert.ok(regex1.test(html1));

  await futureDateInputSelector.expandAwait();
  await futureDateInputSelector.selectRowByValueAwait("pick_date_and_time");

  await fillIn(".future-date-input .date-picker", "2099-11-24");

  assert.equal(futureDateInputSelector.header().title(), "Pick date and time");
  assert.equal(futureDateInputSelector.header().value(), "pick_date_and_time");

  const regex2 = /will automatically open in/g;
  const html2 = find(".future-date-input .topic-status-info")
    .html()
    .trim();
  assert.ok(regex2.test(html2));
});

QUnit.test("schedule", async assert => {
  const timerType = selectKit(".select-kit.timer-type");
  const categoryChooser = selectKit(".modal-body .category-chooser");
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-status-update button");

  await timerType.expandAwait();
  await timerType.selectRowByValueAwait("publish_to_category");

  assert.equal(categoryChooser.header().title(), "uncategorized");
  assert.equal(categoryChooser.header().value(), null);

  assert.equal(futureDateInputSelector.header().title(), "Select a timeframe");
  assert.equal(futureDateInputSelector.header().value(), null);

  await categoryChooser.expandAwait();
  await categoryChooser.selectRowByValueAwait("7");

  await futureDateInputSelector.expandAwait();
  await futureDateInputSelector.selectRowByValueAwait("next_week");

  assert.equal(futureDateInputSelector.header().title(), "Next week");
  assert.equal(futureDateInputSelector.header().value(), "next_week");

  const regex = /will be published to #dev/g;
  const text = find(".future-date-input .topic-status-info")
    .text()
    .trim();
  assert.ok(regex.test(text));
});

QUnit.test("TL4 can't auto-delete", async assert => {
  replaceCurrentUser({ staff: false, trust_level: 4 });

  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-status-update button");

  const timerType = selectKit(".select-kit.timer-type");

  await timerType.expandAwait();

  assert.ok(!timerType.rowByValue("delete").exists());
});

QUnit.test("auto delete", async assert => {
  const timerType = selectKit(".select-kit.timer-type");
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-status-update button");

  await timerType.expandAwait();
  await timerType.selectRowByValueAwait("delete");

  assert.equal(futureDateInputSelector.header().title(), "Select a timeframe");
  assert.equal(futureDateInputSelector.header().value(), null);

  await futureDateInputSelector.expandAwait();
  await futureDateInputSelector.selectRowByValueAwait("two_weeks");

  assert.equal(futureDateInputSelector.header().title(), "Two Weeks");
  assert.equal(futureDateInputSelector.header().value(), "two_weeks");

  const regex = /will be automatically deleted/g;
  const html = find(".future-date-input .topic-status-info")
    .html()
    .trim();
  assert.ok(regex.test(html));
});
