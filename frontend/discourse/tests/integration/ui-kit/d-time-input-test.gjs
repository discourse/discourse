import { tracked } from "@glimmer/tracking";
import { render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import DTimeInput from "discourse/ui-kit/d-time-input";
import I18n from "discourse-i18n";

module("Integration | ui-kit | DTimeInput", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.subject = selectKit();
  });

  test("default", async function (assert) {
    this.hours = "14";
    this.minutes = "58";

    await render(
      <template>
        <DTimeInput @hours={{this.hours}} @minutes={{this.minutes}} />
      </template>
    );

    assert.strictEqual(this.subject.header().name(), "2:58 PM");
  });

  test("prevents mutations", async function (assert) {
    this.hours = "14";
    this.minutes = "58";

    await render(
      <template>
        <DTimeInput @hours={{this.hours}} @minutes={{this.minutes}} />
      </template>
    );

    await this.subject.expand();
    await this.subject.selectRowByIndex(3);
    assert.strictEqual(this.subject.header().name(), "2:58 PM");
  });

  test("allows mutations through actions", async function (assert) {
    const hours = tracked("14");
    const minutes = tracked("58");
    const onChange = (time) => {
      hours.value = time.hours;
      minutes.value = time.minutes;
    };

    await render(
      <template>
        <DTimeInput
          @hours={{hours.value}}
          @minutes={{minutes.value}}
          @onChange={{onChange}}
        />
      </template>
    );

    await this.subject.expand();
    await this.subject.selectRowByIndex(3);
    assert.strictEqual(this.subject.header().name(), "12:45 AM");
  });

  test("clears the time when the date is cleared", async function (assert) {
    const date = tracked(moment("2030-01-15 14:45"));

    await render(<template><DTimeInput @date={{date.value}} /></template>);

    assert.strictEqual(
      this.subject.header().value(),
      "885",
      "selects the date's time"
    );

    date.value = null;
    await rerender();

    assert.strictEqual(
      this.subject.header().value(),
      null,
      "selects nothing once the date is cleared"
    );
  });

  test("renders 24-hour time when the locale's dates.time has no am/pm token", async function (assert) {
    const originalFormat = I18n.translations[I18n.locale].js.dates.time;
    I18n.translations[I18n.locale].js.dates.time = "HH:mm";

    try {
      this.hours = "14";
      this.minutes = "58";

      await render(
        <template>
          <DTimeInput @hours={{this.hours}} @minutes={{this.minutes}} />
        </template>
      );

      assert.strictEqual(this.subject.header().name(), "14:58");
    } finally {
      I18n.translations[I18n.locale].js.dates.time = originalFormat;
    }
  });
});
