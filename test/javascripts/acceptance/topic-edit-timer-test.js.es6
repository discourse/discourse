import { acceptance, replaceCurrentUser } from "helpers/qunit-helpers";
acceptance("Topic - Edit timer", {
  loggedIn: true,
  pretend(server, helper) {
    server.post("/t/280/timer", () =>
      helper.response({
        success: "OK",
        execute_at: new Date(
          new Date().getTime() + 1 * 60 * 60 * 1000
        ).toISOString(),
        duration: 1,
        based_on_last_post: false,
        closed: false,
        category_id: null
      })
    );

    server.put("/t/internationalization-localization/280/status", () =>
      helper.response({
        success: "OK",
        topic_status_update: null
      })
    );
  }
});

QUnit.test("default", async assert => {
  replaceCurrentUser({ admin: true, staff: true, canManageTopic: true });
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
  replaceCurrentUser({ admin: true, staff: true, canManageTopic: true });
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-status-update button");

  await futureDateInputSelector.expand();
  await futureDateInputSelector.selectRowByValue("next_week");

  assert.equal(futureDateInputSelector.header().title(), "Next week");
  assert.equal(futureDateInputSelector.header().value(), "next_week");

  const regex = /will automatically close in/g;
  const html = find(".future-date-input .topic-status-info")
    .html()
    .trim();
  assert.ok(regex.test(html));
});

QUnit.test("autoclose", async assert => {
  replaceCurrentUser({ admin: true, staff: true, canManageTopic: true });
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-status-update button");

  await futureDateInputSelector.expand();
  await futureDateInputSelector.selectRowByValue("next_week");

  assert.equal(futureDateInputSelector.header().title(), "Next week");
  assert.equal(futureDateInputSelector.header().value(), "next_week");

  const regex1 = /will automatically close in/g;
  const html1 = find(".future-date-input .topic-status-info")
    .html()
    .trim();
  assert.ok(regex1.test(html1));

  await futureDateInputSelector.expand();
  await futureDateInputSelector.selectRowByValue("pick_date_and_time");

  await fillIn(".future-date-input .date-picker", "2099-11-24");

  assert.equal(futureDateInputSelector.header().title(), "Pick date and time");
  assert.equal(futureDateInputSelector.header().value(), "pick_date_and_time");

  const regex2 = /will automatically close in/g;
  const html2 = find(".future-date-input .topic-status-info")
    .html()
    .trim();
  assert.ok(regex2.test(html2));

  await futureDateInputSelector.expand();
  await futureDateInputSelector.selectRowByValue("set_based_on_last_post");

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
  replaceCurrentUser({ admin: true, staff: true, canManageTopic: true });
  const timerType = selectKit(".select-kit.timer-type");
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-status-update button");

  await timerType.expand();
  await timerType.selectRowByValue("open");

  assert.equal(futureDateInputSelector.header().title(), "Select a timeframe");
  assert.equal(futureDateInputSelector.header().value(), null);

  await futureDateInputSelector.expand();
  await futureDateInputSelector.selectRowByValue("next_week");

  assert.equal(futureDateInputSelector.header().title(), "Next week");
  assert.equal(futureDateInputSelector.header().value(), "next_week");

  const regex1 = /will automatically open in/g;
  const html1 = find(".future-date-input .topic-status-info")
    .html()
    .trim();
  assert.ok(regex1.test(html1));

  await futureDateInputSelector.expand();
  await futureDateInputSelector.selectRowByValue("pick_date_and_time");

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
  replaceCurrentUser({ admin: true, staff: true, canManageTopic: true });
  const timerType = selectKit(".select-kit.timer-type");
  const categoryChooser = selectKit(".modal-body .category-chooser");
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-status-update button");

  await timerType.expand();
  await timerType.selectRowByValue("publish_to_category");

  assert.equal(categoryChooser.header().title(), "uncategorized");
  assert.equal(categoryChooser.header().value(), null);

  assert.equal(futureDateInputSelector.header().title(), "Select a timeframe");
  assert.equal(futureDateInputSelector.header().value(), null);

  await categoryChooser.expand();
  await categoryChooser.selectRowByValue("7");

  await futureDateInputSelector.expand();
  await futureDateInputSelector.selectRowByValue("next_week");

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

  await timerType.expand();

  assert.ok(!timerType.rowByValue("delete").exists());
});

QUnit.test("auto delete", async assert => {
  replaceCurrentUser({ admin: true, staff: true, canManageTopic: true });
  const timerType = selectKit(".select-kit.timer-type");
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-status-update button");

  await timerType.expand();
  await timerType.selectRowByValue("delete");

  assert.equal(futureDateInputSelector.header().title(), "Select a timeframe");
  assert.equal(futureDateInputSelector.header().value(), null);

  await futureDateInputSelector.expand();
  await futureDateInputSelector.selectRowByValue("two_weeks");

  assert.equal(futureDateInputSelector.header().title(), "Two Weeks");
  assert.equal(futureDateInputSelector.header().value(), "two_weeks");

  const regex = /will be automatically deleted/g;
  const html = find(".future-date-input .topic-status-info")
    .html()
    .trim();
  assert.ok(regex.test(html));
});

QUnit.test(
  "Manually closing before the timer will clear the status text",
  async assert => {
    replaceCurrentUser({ admin: true, staff: true, canManageTopic: true });
    const futureDateInputSelector = selectKit(".future-date-input-selector");

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".topic-admin-status-update button");
    await futureDateInputSelector.expand();
    await futureDateInputSelector.selectRowByValue("next_week");
    await click(".modal-footer button.btn-primary");

    const regex = /will automatically close in/g;
    const topicStatusInfo = find(".topic-status-info")
      .html()
      .trim();
    assert.ok(regex.test(topicStatusInfo));

    await click(".toggle-admin-menu");
    await click(".topic-admin-close button");

    const newTopicStatusInfo = find(".topic-status-info")
      .html()
      .trim();
    assert.notOk(regex.test(newTopicStatusInfo));
  }
);
