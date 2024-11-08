import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";

function dateInput() {
  return query(".date-picker");
}

function timeInput() {
  return query(".d-time-input .combo-box-header");
}

function setDate(date) {
  this.set("date", date);
}

const DEFAULT_DATE_TIME = moment("2019-01-29 14:45");

module("Integration | Component | date-time-input", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE_TIME });

    await render(hbs`<DateTimeInput @date={{this.date}} />`);

    assert.strictEqual(dateInput().value, "2019-01-29");
    assert.strictEqual(timeInput().dataset.name, "14:45");
  });

  test("prevents mutations", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE_TIME });

    await render(hbs`<DateTimeInput @date={{this.date}} />`);

    dateInput().value = "2019-01-02";

    assert.ok(this.date.isSame(DEFAULT_DATE_TIME));
  });

  test("allows mutations through actions", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE_TIME });
    this.set("onChange", setDate);

    await render(
      hbs`<DateTimeInput @date={{this.date}} @onChange={{this.onChange}} />`
    );

    dateInput().value = "2019-01-02";
    dateInput().dispatchEvent(new Event("change"));

    assert.ok(this.date.isSame(moment("2019-01-02 14:45")));
  });

  test("can hide time", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE_TIME });

    await render(
      hbs`<DateTimeInput @date={{this.date}} @showTime={{false}} />`
    );

    assert.dom(timeInput()).exists();
  });

  test("supports swapping timezone without changing visible date/time", async function (assert) {
    this.setProperties({
      date: moment.tz("2023-05-05T12:00:00", "Europe/London"),
      timezone: "Europe/London",
      onChange: setDate,
    });

    await render(
      hbs`<DateTimeInput @date={{this.date}} @timezone={{this.timezone}} @onChange={{this.onChange}} />`
    );
    dateInput().dispatchEvent(new Event("change"));
    assert.strictEqual(this.date.format(), "2023-05-05T12:00:00+01:00");

    this.setProperties({ timezone: "Australia/Sydney" });

    dateInput().dispatchEvent(new Event("change"));
    assert.strictEqual(this.date.format(), "2023-05-05T12:00:00+10:00");
  });
});
