import { fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import DateTimeInput from "discourse/components/date-time-input";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const DEFAULT_DATE_TIME = moment("2019-01-29 14:45");

module("Integration | Component | date-time-input", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    const self = this;

    this.setProperties({ date: DEFAULT_DATE_TIME });

    await render(<template><DateTimeInput @date={{self.date}} /></template>);

    assert.dom(".date-picker").hasValue("2019-01-29");
    assert
      .dom(".d-time-input .combo-box-header")
      .hasAttribute("data-name", "14:45");
  });

  test("prevents mutations", async function (assert) {
    const self = this;

    this.setProperties({ date: DEFAULT_DATE_TIME });

    await render(<template><DateTimeInput @date={{self.date}} /></template>);

    await fillIn(".date-picker", "2019-01-02");

    assert.true(this.date.isSame(DEFAULT_DATE_TIME));
  });

  test("allows mutations through actions", async function (assert) {
    const self = this;

    this.setProperties({ date: DEFAULT_DATE_TIME });
    this.set("onChange", (date) => this.set("date", date));

    await render(
      <template>
        <DateTimeInput @date={{self.date}} @onChange={{self.onChange}} />
      </template>
    );

    await fillIn(".date-picker", "2019-01-02");
    await triggerEvent(".date-picker", "change");

    assert.true(this.date.isSame(moment("2019-01-02 14:45")));
  });

  test("can hide time", async function (assert) {
    const self = this;

    this.setProperties({ date: DEFAULT_DATE_TIME });

    await render(
      <template>
        <DateTimeInput @date={{self.date}} @showTime={{false}} />
      </template>
    );

    assert.dom(".d-time-input .combo-box-header").doesNotExist();
  });

  test("supports swapping timezone without changing visible date/time", async function (assert) {
    const self = this;

    this.setProperties({
      date: moment.tz("2023-05-05T12:00:00", "Europe/London"),
      timezone: "Europe/London",
      onChange: (date) => this.set("date", date),
    });

    await render(
      <template>
        <DateTimeInput
          @date={{self.date}}
          @timezone={{self.timezone}}
          @onChange={{self.onChange}}
        />
      </template>
    );
    await triggerEvent(".date-picker", "change");
    assert.strictEqual(this.date.format(), "2023-05-05T12:00:00+01:00");

    this.setProperties({ timezone: "Australia/Sydney" });

    await triggerEvent(".date-picker", "change");
    assert.strictEqual(this.date.format(), "2023-05-05T12:00:00+10:00");
  });
});
