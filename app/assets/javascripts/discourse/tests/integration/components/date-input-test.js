import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const DEFAULT_DATE = moment("2019-01-29");

module("Integration | Component | date-input", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE });

    await render(hbs`<DateInput @date={{this.date}} />`);

    assert.dom(".date-picker").hasValue("2019-01-29");
  });

  test("prevents mutations", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE });
    this.set("onChange", () => {});

    await render(
      hbs`<DateInput @date={{this.date}} @onChange={{this.onChange}} />`
    );

    document.querySelector(".date-picker").value = "2019-01-02";
    document.querySelector(".date-picker").dispatchEvent(new Event("change"));

    assert.true(this.date.isSame(DEFAULT_DATE));
  });

  test("allows mutations through actions", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE });
    this.set("onChange", (date) => this.set("date", date));

    await render(
      hbs`<DateInput @date={{this.date}} @onChange={{this.onChange}} />`
    );

    document.querySelector(".date-picker").value = "2019-02-02";
    document.querySelector(".date-picker").dispatchEvent(new Event("change"));

    assert.true(this.date.isSame(moment("2019-02-02")));
  });

  test("always shows date in timezone of input timestamp", async function (assert) {
    this.setProperties({
      date: moment.tz("2023-05-05T10:00:00", "ETC/GMT-12"),
    });

    await render(
      hbs`<DateInput @date={{this.date}} @onChange={{this.onChange}} />`
    );
    assert.dom(".date-picker").hasValue("2023-05-05");

    this.setProperties({
      date: moment.tz("2023-05-05T10:00:00", "ETC/GMT+12"),
    });
    assert.dom(".date-picker").hasValue("2023-05-05");
  });
});
