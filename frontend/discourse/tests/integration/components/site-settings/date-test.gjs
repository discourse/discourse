import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DateSetting from "discourse/admin/components/site-settings/date";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | SiteSettings | Date", function (hooks) {
  setupRenderingTest(hooks);

  test("shows and stores an ISO 8601 date", async function (assert) {
    this.value = "2026-07-01";
    this.changeValue = (value) => (this.value = value);

    await render(
      <template>
        <DateSetting
          @changeValueCallback={{this.changeValue}}
          @value={{this.value}}
        />
      </template>
    );

    assert
      .dom(".input-setting-date")
      .hasValue("2026-07-01", "the input shows the stored date");

    await fillIn(".input-setting-date", "2026-07-02");

    assert.strictEqual(
      this.value,
      "2026-07-02",
      "the input stores the selected date"
    );

    assert
      .dom(".btn-small")
      .hasAttribute("aria-label", "reset", "the clear button has a label");

    await click(".btn-small");

    assert.strictEqual(this.value, "", "the clear button stores a blank value");
  });
});
