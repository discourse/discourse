import { fillIn, render, triggerEvent } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function setDate(date) {
  this.set("date", date);
}

const DEFAULT_DATE_TIME = moment("2019-01-29 14:45");

module("Integration | Component | date-time-input", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE_TIME });

    await render(hbs`<DateTimeInput @date={{this.date}} />`);

    assert.dom(".date-picker").hasValue("2019-01-29");
    assert
      .dom(".d-time-input .combo-box-header")
      .hasAttribute("data-name", "14:45");
  });

  test("prevents mutations", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE_TIME });

    await render(hbs`<DateTimeInput @date={{this.date}} />`);

    await fillIn(".date-picker", "2019-01-02");

    assert.true(this.date.isSame(DEFAULT_DATE_TIME));
  });

  test("allows mutations through actions", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE_TIME });
    this.set("onChange", setDate);

    await render(
      hbs`<DateTimeInput @date={{this.date}} @onChange={{this.onChange}} />`
    );

    await fillIn(".date-picker", "2019-01-02");
    await triggerEvent(".date-picker", "change");

    assert.true(this.date.isSame(moment("2019-01-02 14:45")));
  });

  test("can hide time", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE_TIME });

    await render(
      hbs`<DateTimeInput @date={{this.date}} @showTime={{false}} />`
    );

    assert.dom(".d-time-input .combo-box-header").doesNotExist();
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
    await triggerEvent(".date-picker", "change");
    assert.strictEqual(this.date.format(), "2023-05-05T12:00:00+01:00");

    this.setProperties({ timezone: "Australia/Sydney" });

    await triggerEvent(".date-picker", "change");
    assert.strictEqual(this.date.format(), "2023-05-05T12:00:00+10:00");
  });
});
