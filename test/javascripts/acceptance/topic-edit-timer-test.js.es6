import { acceptance, replaceCurrentUser } from "helpers/qunit-helpers";
acceptance("Topic - Edit timer", { loggedIn: true });

QUnit.test("default", assert => {
  const timerType = selectKit(".select-kit.timer-type");
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  visit("/t/internationalization-localization");
  click(".toggle-admin-menu");
  click(".topic-admin-status-update button");

  andThen(() => {
    assert.equal(
      futureDateInputSelector.header().title(),
      "Select a timeframe"
    );
    assert.equal(futureDateInputSelector.header().value(), null);
  });

  click("#private-topic-timer");

  andThen(() => {
    assert.equal(timerType.header().title(), "Remind Me");
    assert.equal(timerType.header().value(), "reminder");

    assert.equal(
      futureDateInputSelector.header().title(),
      "Select a timeframe"
    );
    assert.equal(futureDateInputSelector.header().value(), null);
  });
});

QUnit.test("autoclose - specific time", assert => {
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  visit("/t/internationalization-localization");
  click(".toggle-admin-menu");
  click(".topic-admin-status-update button");

  futureDateInputSelector.expand().selectRowByValue("next_week");

  andThen(() => {
    assert.equal(futureDateInputSelector.header().title(), "Next week");
    assert.equal(futureDateInputSelector.header().value(), "next_week");

    const regex = /will automatically close in/g;
    const html = find(".future-date-input .topic-status-info")
      .html()
      .trim();
    assert.ok(regex.test(html));
  });
});

QUnit.test("autoclose", assert => {
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  visit("/t/internationalization-localization");
  click(".toggle-admin-menu");
  click(".topic-admin-status-update button");

  futureDateInputSelector.expand().selectRowByValue("next_week");

  andThen(() => {
    assert.equal(futureDateInputSelector.header().title(), "Next week");
    assert.equal(futureDateInputSelector.header().value(), "next_week");

    const regex = /will automatically close in/g;
    const html = find(".future-date-input .topic-status-info")
      .html()
      .trim();
    assert.ok(regex.test(html));
  });

  futureDateInputSelector.expand().selectRowByValue("pick_date_and_time");

  fillIn(".future-date-input .date-picker", "2099-11-24");

  andThen(() => {
    assert.equal(
      futureDateInputSelector.header().title(),
      "Pick date and time"
    );
    assert.equal(
      futureDateInputSelector.header().value(),
      "pick_date_and_time"
    );

    const regex = /will automatically close in/g;
    const html = find(".future-date-input .topic-status-info")
      .html()
      .trim();
    assert.ok(regex.test(html));
  });

  futureDateInputSelector.expand().selectRowByValue("set_based_on_last_post");

  fillIn(".future-date-input input[type=number]", "2");

  andThen(() => {
    assert.equal(
      futureDateInputSelector.header().title(),
      "Close based on last post"
    );
    assert.equal(
      futureDateInputSelector.header().value(),
      "set_based_on_last_post"
    );

    const regex = /This topic will close.*after the last reply/g;
    const html = find(".future-date-input .topic-status-info")
      .html()
      .trim();
    assert.ok(regex.test(html));
  });
});

QUnit.test("close temporarily", assert => {
  const timerType = selectKit(".select-kit.timer-type");
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  visit("/t/internationalization-localization");
  click(".toggle-admin-menu");
  click(".topic-admin-status-update button");

  timerType.expand().selectRowByValue("open");

  andThen(() => {
    assert.equal(
      futureDateInputSelector.header().title(),
      "Select a timeframe"
    );
    assert.equal(futureDateInputSelector.header().value(), null);
  });

  futureDateInputSelector.expand().selectRowByValue("next_week");

  andThen(() => {
    assert.equal(futureDateInputSelector.header().title(), "Next week");
    assert.equal(futureDateInputSelector.header().value(), "next_week");

    const regex = /will automatically open in/g;
    const html = find(".future-date-input .topic-status-info")
      .html()
      .trim();
    assert.ok(regex.test(html));
  });

  futureDateInputSelector.expand().selectRowByValue("pick_date_and_time");

  fillIn(".future-date-input .date-picker", "2099-11-24");

  andThen(() => {
    assert.equal(
      futureDateInputSelector.header().title(),
      "Pick date and time"
    );
    assert.equal(
      futureDateInputSelector.header().value(),
      "pick_date_and_time"
    );

    const regex = /will automatically open in/g;
    const html = find(".future-date-input .topic-status-info")
      .html()
      .trim();
    assert.ok(regex.test(html));
  });
});

QUnit.test("schedule", assert => {
  const timerType = selectKit(".select-kit.timer-type");
  const categoryChooser = selectKit(".modal-body .category-chooser");
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  visit("/t/internationalization-localization");
  click(".toggle-admin-menu");
  click(".topic-admin-status-update button");

  timerType.expand().selectRowByValue("publish_to_category");

  andThen(() => {
    assert.equal(categoryChooser.header().title(), "uncategorized");
    assert.equal(categoryChooser.header().value(), null);

    assert.equal(
      futureDateInputSelector.header().title(),
      "Select a timeframe"
    );
    assert.equal(futureDateInputSelector.header().value(), null);
  });

  categoryChooser.expand().selectRowByValue("7");

  futureDateInputSelector.expand().selectRowByValue("next_week");

  andThen(() => {
    assert.equal(futureDateInputSelector.header().title(), "Next week");
    assert.equal(futureDateInputSelector.header().value(), "next_week");

    const regex = /will be published to #dev/g;
    const text = find(".future-date-input .topic-status-info")
      .text()
      .trim();
    assert.ok(regex.test(text));
  });
});

QUnit.test("TL4 can't auto-delete", assert => {
  replaceCurrentUser({ staff: false, trust_level: 4 });

  visit("/t/internationalization-localization");
  click(".toggle-admin-menu");
  click(".topic-admin-status-update button");

  const timerType = selectKit(".select-kit.timer-type");

  timerType.expand();

  andThen(() => {
    assert.ok(!timerType.rowByValue("delete").exists());
  });
});

QUnit.test("auto delete", assert => {
  const timerType = selectKit(".select-kit.timer-type");
  const futureDateInputSelector = selectKit(".future-date-input-selector");

  visit("/t/internationalization-localization");
  click(".toggle-admin-menu");
  click(".topic-admin-status-update button");

  timerType.expand().selectRowByValue("delete");

  andThen(() => {
    assert.equal(
      futureDateInputSelector.header().title(),
      "Select a timeframe"
    );
    assert.equal(futureDateInputSelector.header().value(), null);
  });

  futureDateInputSelector.expand().selectRowByValue("two_weeks");

  andThen(() => {
    assert.equal(futureDateInputSelector.header().title(), "Two Weeks");
    assert.equal(futureDateInputSelector.header().value(), "two_weeks");

    const regex = /will be automatically deleted/g;
    const html = find(".future-date-input .topic-status-info")
      .html()
      .trim();
    assert.ok(regex.test(html));
  });
});
