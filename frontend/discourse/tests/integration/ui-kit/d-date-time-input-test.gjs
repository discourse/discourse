import { fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import DDateTimeInput from "discourse/ui-kit/d-date-time-input";

const DEFAULT_DATE_TIME = moment("2019-01-29 14:45");

/**
 * A southern and a northern summer day that predate the bundled tz data, so
 * only the browser's own rules know their DST offsets.
 */
const OUT_OF_DATA_RANGE_DAYS = ["2019-01-29", "2019-07-15"];

module("Integration | ui-kit | DDateTimeInput", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE_TIME });

    await render(<template><DDateTimeInput @date={{this.date}} /></template>);

    assert.dom(".date-picker").hasValue("2019-01-29");
    assert
      .dom(".d-time-input .combo-box-header")
      .hasAttribute("data-name", "2:45 PM");
  });

  test("prevents mutations", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE_TIME });

    await render(<template><DDateTimeInput @date={{this.date}} /></template>);

    await fillIn(".date-picker", "2019-01-02");

    assert.true(this.date.isSame(DEFAULT_DATE_TIME));
  });

  test("allows mutations through actions", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE_TIME });
    this.set("onChange", (date) => this.set("date", date));

    await render(
      <template>
        <DDateTimeInput @date={{this.date}} @onChange={{this.onChange}} />
      </template>
    );

    await fillIn(".date-picker", "2019-01-02");
    await triggerEvent(".date-picker", "change");

    assert.strictEqual(
      this.date.format("YYYY-MM-DD HH:mm"),
      "2019-01-02 14:45",
      "it preserves the original time when changing the date"
    );
  });

  test("can hide time", async function (assert) {
    this.setProperties({ date: DEFAULT_DATE_TIME });

    await render(
      <template>
        <DDateTimeInput @date={{this.date}} @showTime={{false}} />
      </template>
    );

    assert.dom(".d-time-input .combo-box-header").doesNotExist();
  });

  test("supports swapping timezone without changing visible date/time", async function (assert) {
    this.setProperties({
      date: moment.tz("2023-05-05T12:00:00", "Europe/London"),
      timezone: "Europe/London",
      onChange: (date) => this.set("date", date),
    });

    await render(
      <template>
        <DDateTimeInput
          @date={{this.date}}
          @onChange={{this.onChange}}
          @timezone={{this.timezone}}
        />
      </template>
    );
    await triggerEvent(".date-picker", "change");
    assert.strictEqual(this.date.format(), "2023-05-05T12:00:00+01:00");

    this.setProperties({ timezone: "Australia/Sydney" });

    await triggerEvent(".date-picker", "change");
    assert.strictEqual(this.date.format(), "2023-05-05T12:00:00+10:00");
  });

  test("without @timezone a picked time keeps the browser's offset for that day", async function (assert) {
    for (const day of OUT_OF_DATA_RANGE_DAYS) {
      this.setProperties({
        date: moment(`${day} 10:00`),
        onChange: (date) => this.set("date", date),
      });

      await render(
        <template>
          <DDateTimeInput @date={{this.date}} @onChange={{this.onChange}} />
        </template>
      );

      const timeSelectKit = selectKit(".d-time-input .select-kit");
      await timeSelectKit.expand();
      await timeSelectKit.selectRowByName("2:45 PM");

      assert.strictEqual(
        this.date.toISOString(),
        moment(`${day} 14:45`).toISOString(),
        `picking a time on ${day} resolves to the local instant`
      );
      assert.strictEqual(
        this.date.format("YYYY-MM-DD HH:mm"),
        `${day} 14:45`,
        `picking a time on ${day} keeps the picked wall time`
      );
    }
  });

  test("without @timezone a picked date keeps the browser's offset for that day", async function (assert) {
    for (const day of OUT_OF_DATA_RANGE_DAYS) {
      this.setProperties({
        date: moment("2026-05-05 14:45"),
        onChange: (date) => this.set("date", date),
      });

      await render(
        <template>
          <DDateTimeInput @date={{this.date}} @onChange={{this.onChange}} />
        </template>
      );

      await fillIn(".date-picker", day);
      await triggerEvent(".date-picker", "change");

      assert.strictEqual(
        this.date.toISOString(),
        moment(`${day} 14:45`).toISOString(),
        `picking ${day} resolves to the local instant`
      );
      assert.strictEqual(
        this.date.format("YYYY-MM-DD HH:mm"),
        `${day} 14:45`,
        `picking ${day} keeps the picked wall time`
      );
    }
  });

  test("without @timezone a time picked relative to @relativeDate keeps the browser's offset", async function (assert) {
    for (const day of OUT_OF_DATA_RANGE_DAYS) {
      this.setProperties({
        date: null,
        relativeDate: moment(`${day} 10:00`),
        onChange: (date) => this.set("date", date),
      });

      await render(
        <template>
          <DDateTimeInput
            @date={{this.date}}
            @onChange={{this.onChange}}
            @relativeDate={{this.relativeDate}}
          />
        </template>
      );

      const timeSelectKit = selectKit(".d-time-input .select-kit");
      await timeSelectKit.expand();
      await timeSelectKit.selectRowByName("11:00 AM");

      assert.strictEqual(
        this.date.toISOString(),
        moment(`${day} 11:00`).toISOString(),
        `picking a time after ${day} 10:00 resolves to the local instant`
      );
      assert.strictEqual(
        this.date.format("YYYY-MM-DD HH:mm"),
        `${day} 11:00`,
        `picking a time after ${day} 10:00 keeps the picked wall time`
      );
    }
  });

  test("exposes its inputs to subclasses by name", async function (assert) {
    class Subclass extends DDateTimeInput {
      <template>
        <span class="probe">{{if this.date "dated"}}
          {{this.showTime}}
          {{this.clearable}}</span>
      </template>
    }
    this.setProperties({ date: DEFAULT_DATE_TIME });

    await render(<template><Subclass @date={{this.date}} /></template>);

    assert.dom(".probe").hasText("dated true false");
  });
});
