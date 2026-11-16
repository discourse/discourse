import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  registerUniversalDeprecationHandler,
  unregisterUniversalDeprecationHandler,
} from "discourse/lib/deprecated";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import DTimeInput from "discourse/ui-kit/d-time-input";
import I18n from "discourse-i18n";

function setTime(time) {
  this.setProperties(time);
}

module("Integration | ui-kit | DTimeInput", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("is deprecated in favour of a native time input", async function (assert) {
    const ids = [];
    const handler = (_message, options) => ids.push(options?.id);
    registerUniversalDeprecationHandler(handler);

    try {
      await render(<template><DTimeInput /></template>);
    } finally {
      unregisterUniversalDeprecationHandler(handler);
    }

    assert.true(
      ids.includes("discourse.d-time-input"),
      "rendering it reports the deprecation"
    );
  });

  test("default", async function (assert) {
    this.setProperties({ hours: "14", minutes: "58" });

    await render(
      <template>
        <DTimeInput @hours={{this.hours}} @minutes={{this.minutes}} />
      </template>
    );

    assert.strictEqual(this.subject.header().name(), "2:58 PM");
  });

  test("prevents mutations", async function (assert) {
    this.setProperties({ hours: "14", minutes: "58" });

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
    this.setProperties({ hours: "14", minutes: "58" });
    this.set("onChange", setTime);

    await render(
      <template>
        <DTimeInput
          @hours={{this.hours}}
          @minutes={{this.minutes}}
          @onChange={{this.onChange}}
        />
      </template>
    );

    await this.subject.expand();
    await this.subject.selectRowByIndex(3);
    assert.strictEqual(this.subject.header().name(), "12:45 AM");
  });

  test("renders 24-hour time when the locale's dates.time has no am/pm token", async function (assert) {
    const originalFormat = I18n.translations[I18n.locale].js.dates.time;
    I18n.translations[I18n.locale].js.dates.time = "HH:mm";

    try {
      this.setProperties({ hours: "14", minutes: "58" });

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
