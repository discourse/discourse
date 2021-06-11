import {
  acceptance,
  count,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";

acceptance("User notification schedule", function (needs) {
  needs.user();

  test("the schedule interface is hidden until enabled", async function (assert) {
    await visit("/u/eviltrout/preferences/notifications");

    assert.ok(
      !exists(".notification-schedule-table"),
      "notification schedule is hidden"
    );
    await click(".control-group.notification-schedule input");
    assert.ok(
      exists(".notification-schedule-table"),
      "notification schedule is visible"
    );
  });

  test("By default every day is selected 8:00am - 5:00pm", async function (assert) {
    await visit("/u/eviltrout/preferences/notifications");
    await click(".control-group.notification-schedule input");

    [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ].forEach((day) => {
      assert.equal(
        selectKit(`.day.${day} .starts-at .combobox`).header().label(),
        "8:00 AM",
        "8am is selected"
      );
      assert.equal(
        selectKit(`.day.${day} .starts-at .combobox`).header().value(),
        "480",
        "8am is 480"
      );
      assert.equal(
        selectKit(`.day.${day} .ends-at .combobox`).header().label(),
        "5:00 PM",
        "5am is selected"
      );
      assert.equal(
        selectKit(`.day.${day} .ends-at .combobox`).header().value(),
        "1020",
        "5pm is 1020"
      );
    });
  });

  test("If 'none' is selected for the start time, end time dropdown is removed", async function (assert) {
    await visit("/u/eviltrout/preferences/notifications");
    await click(".control-group.notification-schedule input");

    await selectKit(".day.Monday .combobox").expand();
    await selectKit(".day.Monday .combobox").selectRowByValue(-1);

    assert.equal(
      selectKit(".day.Monday .starts-at .combobox").header().value(),
      "-1",
      "set monday input to none"
    );
    assert.equal(
      selectKit(".day.Monday .starts-at .combobox").header().label(),
      "None",
      "set monday label to none"
    );
    assert.equal(
      count(".day.Monday .select-kit.single-select"),
      1,
      "The end time input is hidden"
    );
  });

  test("If start time is after end time, end time gets bumped 30 minutes past start time", async function (assert) {
    await visit("/u/eviltrout/preferences/notifications");
    await click(".control-group.notification-schedule input");

    await selectKit(".day.Tuesday .starts-at .combobox").expand();
    await selectKit(".day.Tuesday .starts-at .combobox").selectRowByValue(
      "1350"
    );

    assert.equal(
      selectKit(".day.Tuesday .ends-at .combobox").header().value(),
      "1380",
      "End time is 30 past start time"
    );

    await selectKit(".day.Tuesday .ends-at .combobox").expand();
    assert.ok(
      !selectKit(".day.Tuesday .ends-at .combobox").rowByValue(1350).exists(),
      "End time options are limited to + 30 past start time"
    );
  });
});
