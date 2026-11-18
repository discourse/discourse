import { tracked } from "@glimmer/tracking";
import {
  click,
  fillIn,
  render,
  rerender,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
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
    this.date = DEFAULT_DATE_TIME;

    await render(<template><DDateTimeInput @date={{this.date}} /></template>);

    assert.dom(".date-picker").hasValue("2019-01-29");
    assert.dom(".time-input").hasAttribute("type", "time").hasValue("14:45");
  });

  test("prevents mutations", async function (assert) {
    this.date = DEFAULT_DATE_TIME;

    await render(<template><DDateTimeInput @date={{this.date}} /></template>);

    await fillIn(".date-picker", "2019-01-02");

    assert.true(this.date.isSame(DEFAULT_DATE_TIME));
  });

  test("allows mutations through actions", async function (assert) {
    const date = tracked(DEFAULT_DATE_TIME);
    const onChange = (newDate) => (date.value = newDate);

    await render(
      <template>
        <DDateTimeInput @date={{date.value}} @onChange={{onChange}} />
      </template>
    );

    await fillIn(".date-picker", "2019-01-02");
    await triggerEvent(".date-picker", "change");

    assert.strictEqual(
      date.value.format("YYYY-MM-DD HH:mm"),
      "2019-01-02 14:45",
      "it preserves the original time when changing the date"
    );
  });

  test("the clear button calls @onChange with null", async function (assert) {
    const changes = [];
    const onChange = (date) => changes.push(date);

    await render(
      <template>
        <DDateTimeInput
          @clearable={{true}}
          @date={{DEFAULT_DATE_TIME}}
          @onChange={{onChange}}
        />
      </template>
    );

    await click(".clear-date-time");

    assert.deepEqual(changes, [null], "it reports the cleared value");
  });

  test("the clear button does nothing without @onChange", async function (assert) {
    await render(
      <template>
        <DDateTimeInput @clearable={{true}} @date={{DEFAULT_DATE_TIME}} />
      </template>
    );

    await click(".clear-date-time");

    assert
      .dom(".date-picker")
      .hasValue("2019-01-29", "it keeps showing the date");
  });

  test("emptying the time reports nothing", async function (assert) {
    const changes = [];
    const onChange = (date) => changes.push(date);

    await render(
      <template>
        <DDateTimeInput @date={{DEFAULT_DATE_TIME}} @onChange={{onChange}} />
      </template>
    );

    await fillIn(".time-input", "");

    assert.deepEqual(changes, [], "the date keeps its time");
  });

  test("emptying the date does nothing without @onChange", async function (assert) {
    await render(
      <template><DDateTimeInput @date={{DEFAULT_DATE_TIME}} /></template>
    );

    await fillIn(".date-picker", "");

    assert.dom(".date-picker").hasValue("", "it accepts the empty input");
  });

  test("can hide time", async function (assert) {
    this.date = DEFAULT_DATE_TIME;

    await render(
      <template>
        <DDateTimeInput @date={{this.date}} @showTime={{false}} />
      </template>
    );

    assert.dom(".time-input").doesNotExist();
  });

  test("supports swapping timezone without changing visible date/time", async function (assert) {
    const date = tracked(moment.tz("2023-05-05T12:00:00", "Europe/London"));
    const timezone = tracked("Europe/London");
    const onChange = (newDate) => (date.value = newDate);

    await render(
      <template>
        <DDateTimeInput
          @date={{date.value}}
          @onChange={{onChange}}
          @timezone={{timezone.value}}
        />
      </template>
    );
    await triggerEvent(".date-picker", "change");
    assert.strictEqual(date.value.format(), "2023-05-05T12:00:00+01:00");

    timezone.value = "Australia/Sydney";
    await rerender();

    await triggerEvent(".date-picker", "change");
    assert.strictEqual(date.value.format(), "2023-05-05T12:00:00+10:00");
  });

  test("without @timezone a picked time keeps the browser's offset for that day", async function (assert) {
    for (const day of OUT_OF_DATA_RANGE_DAYS) {
      const date = tracked(moment(`${day} 10:00`));
      const onChange = (newDate) => (date.value = newDate);

      await render(
        <template>
          <DDateTimeInput @date={{date.value}} @onChange={{onChange}} />
        </template>
      );

      await fillIn(".time-input", "14:45");

      assert.strictEqual(
        date.value.toISOString(),
        moment(`${day} 14:45`).toISOString(),
        `picking a time on ${day} resolves to the local instant`
      );
      assert.strictEqual(
        date.value.format("YYYY-MM-DD HH:mm"),
        `${day} 14:45`,
        `picking a time on ${day} keeps the picked wall time`
      );
    }
  });

  test("without @timezone a picked date keeps the browser's offset for that day", async function (assert) {
    for (const day of OUT_OF_DATA_RANGE_DAYS) {
      const date = tracked(moment("2026-05-05 14:45"));
      const onChange = (newDate) => (date.value = newDate);

      await render(
        <template>
          <DDateTimeInput @date={{date.value}} @onChange={{onChange}} />
        </template>
      );

      await fillIn(".date-picker", day);
      await triggerEvent(".date-picker", "change");

      assert.strictEqual(
        date.value.toISOString(),
        moment(`${day} 14:45`).toISOString(),
        `picking ${day} resolves to the local instant`
      );
      assert.strictEqual(
        date.value.format("YYYY-MM-DD HH:mm"),
        `${day} 14:45`,
        `picking ${day} keeps the picked wall time`
      );
    }
  });

  test("without @timezone a time picked relative to @relativeDate keeps the browser's offset", async function (assert) {
    for (const day of OUT_OF_DATA_RANGE_DAYS) {
      const date = tracked(null);
      const relativeDate = moment(`${day} 10:00`);
      const onChange = (newDate) => (date.value = newDate);

      await render(
        <template>
          <DDateTimeInput
            @date={{date.value}}
            @onChange={{onChange}}
            @relativeDate={{relativeDate}}
          />
        </template>
      );

      await fillIn(".time-input", "11:00");

      assert.strictEqual(
        date.value.toISOString(),
        moment(`${day} 11:00`).toISOString(),
        `picking a time after ${day} 10:00 resolves to the local instant`
      );
      assert.strictEqual(
        date.value.format("YYYY-MM-DD HH:mm"),
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
    this.date = DEFAULT_DATE_TIME;

    await render(<template><Subclass @date={{this.date}} /></template>);

    assert.dom(".probe").hasText("dated true false");
  });

  test("has no clear button without @clearable", async function (assert) {
    await render(
      <template><DDateTimeInput @date={{DEFAULT_DATE_TIME}} /></template>
    );

    assert
      .dom(".clear-date-time")
      .doesNotExist("there is no clear button without @clearable");
  });

  test("@timeFirst shows the time before the date", async function (assert) {
    await render(
      <template>
        <div class="date-first">
          <DDateTimeInput @date={{DEFAULT_DATE_TIME}} />
        </div>
        <div class="time-first">
          <DDateTimeInput @date={{DEFAULT_DATE_TIME}} @timeFirst={{true}} />
        </div>
      </template>
    );

    assert
      .dom(".date-first .d-date-time-input > :first-child")
      .hasClass("d-date-input", "the date comes first by default");
    assert
      .dom(".time-first .d-date-time-input > :first-child")
      .hasClass("time-input", "@timeFirst moves the time first");
    assert
      .dom(".time-first .d-date-input")
      .exists({ count: 1 }, "the date is still shown once");
  });
});
