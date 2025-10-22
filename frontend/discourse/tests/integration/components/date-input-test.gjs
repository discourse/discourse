import { fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import DateInput from "discourse/components/date-input";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const DEFAULT_DATE = moment("2019-01-29");

module("Integration | Component | date-input", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    const self = this;

    this.setProperties({ date: DEFAULT_DATE });

    await render(<template><DateInput @date={{self.date}} /></template>);

    assert.dom(".date-picker").hasValue("2019-01-29");
  });

  test("prevents mutations", async function (assert) {
    const self = this;

    this.setProperties({ date: DEFAULT_DATE });
    this.set("onChange", () => {});

    await render(
      <template>
        <DateInput @date={{self.date}} @onChange={{self.onChange}} />
      </template>
    );

    await fillIn(".date-picker", "2019-01-02");
    await triggerEvent(".date-picker", "change");

    assert.true(this.date.isSame(DEFAULT_DATE));
  });

  test("allows mutations through actions", async function (assert) {
    const self = this;

    this.setProperties({ date: DEFAULT_DATE });
    this.set("onChange", (date) => this.set("date", date));

    await render(
      <template>
        <DateInput @date={{self.date}} @onChange={{self.onChange}} />
      </template>
    );

    await fillIn(".date-picker", "2019-02-02");
    await triggerEvent(".date-picker", "change");

    assert.true(this.date.isSame(moment("2019-02-02")));
  });

  test("always shows date in timezone of input timestamp", async function (assert) {
    const self = this;

    this.setProperties({
      date: moment.tz("2023-05-05T10:00:00", "ETC/GMT-12"),
    });

    await render(
      <template>
        <DateInput @date={{self.date}} @onChange={{self.onChange}} />
      </template>
    );
    assert.dom(".date-picker").hasValue("2023-05-05");

    this.setProperties({
      date: moment.tz("2023-05-05T10:00:00", "ETC/GMT+12"),
    });
    assert.dom(".date-picker").hasValue("2023-05-05");
  });
});
