import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

function dateInput() {
  return query(".date-picker");
}

function setDate(date) {
  this.set("date", date);
}

function noop() {}

const DEFAULT_DATE = moment("2019-01-29");

module("Integration | Component | date-input", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE });

    await render(hbs`<DateInput @date={{this.date}} />`);

    assert.strictEqual(dateInput().value, "2019-01-29");
  });

  test("prevents mutations", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE });
    this.set("onChange", noop);

    await render(
      hbs`<DateInput @date={{this.date}} @onChange={{this.onChange}} />`
    );

    dateInput().value = "2019-01-02";
    dateInput().dispatchEvent(new Event("change"));

    assert.ok(this.date.isSame(DEFAULT_DATE));
  });

  test("allows mutations through actions", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE });
    this.set("onChange", setDate);

    await render(
      hbs`<DateInput @date={{this.date}} @onChange={{this.onChange}} />`
    );

    dateInput().value = "2019-02-02";
    dateInput().dispatchEvent(new Event("change"));

    assert.ok(this.date.isSame(moment("2019-02-02")));
  });

  test("always shows date in timezone of input timestamp", async function (assert) {
    this.setProperties({
      date: moment.tz("2023-05-05T10:00:00", "ETC/GMT-12"),
    });

    await render(
      hbs`<DateInput @date={{this.date}} @onChange={{this.onChange}} />`
    );
    assert.strictEqual(dateInput().value, "2023-05-05");

    this.setProperties({
      date: moment.tz("2023-05-05T10:00:00", "ETC/GMT+12"),
    });
    assert.strictEqual(dateInput().value, "2023-05-05");
  });
});
