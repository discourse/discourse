import { tracked } from "@glimmer/tracking";
import {
  fillIn,
  render,
  rerender,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DDateInput from "discourse/ui-kit/d-date-input";

const DEFAULT_DATE = moment("2019-01-29");

module("Integration | ui-kit | DDateInput", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    this.date = DEFAULT_DATE;

    await render(<template><DDateInput @date={{this.date}} /></template>);

    assert.dom(".date-picker").hasValue("2019-01-29");
  });

  test("prevents mutations", async function (assert) {
    this.date = DEFAULT_DATE;
    this.onChange = () => {};

    await render(
      <template>
        <DDateInput @date={{this.date}} @onChange={{this.onChange}} />
      </template>
    );

    await fillIn(".date-picker", "2019-01-02");
    await triggerEvent(".date-picker", "change");

    assert.true(this.date.isSame(DEFAULT_DATE));
  });

  test("allows mutations through actions", async function (assert) {
    const date = tracked(DEFAULT_DATE);
    const onChange = (newDate) => (date.value = newDate);

    await render(
      <template>
        <DDateInput @date={{date.value}} @onChange={{onChange}} />
      </template>
    );

    await fillIn(".date-picker", "2019-02-02");
    await triggerEvent(".date-picker", "change");

    assert.true(date.value.isSame(moment("2019-02-02")));
  });

  test("bounds the picker to the relative date and follows its changes", async function (assert) {
    const relativeDate = tracked(moment("2019-01-20"));

    await render(
      <template>
        <DDateInput
          @date={{DEFAULT_DATE}}
          @relativeDate={{relativeDate.value}}
        />
      </template>
    );

    assert
      .dom(".date-picker")
      .hasAttribute("min", "2019-01-20", "the bound is applied on load");

    relativeDate.value = moment("2019-01-25");
    await settled();

    assert
      .dom(".date-picker")
      .hasAttribute("min", "2019-01-25", "the bound tracks the relative date");

    relativeDate.value = null;
    await settled();

    assert
      .dom(".date-picker")
      .hasAttribute("min", "", "the bound is dropped with the relative date");
  });

  test("always shows date in timezone of input timestamp", async function (assert) {
    const date = tracked(moment.tz("2023-05-05T10:00:00", "ETC/GMT-12"));

    await render(<template><DDateInput @date={{date.value}} /></template>);
    assert.dom(".date-picker").hasValue("2023-05-05");

    date.value = moment.tz("2023-05-05T10:00:00", "ETC/GMT+12");
    await rerender();
    assert.dom(".date-picker").hasValue("2023-05-05");
  });
});
