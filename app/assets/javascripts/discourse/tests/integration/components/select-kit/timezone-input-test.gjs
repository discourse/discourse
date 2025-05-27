import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import TimezoneInput from "select-kit/components/timezone-input";

module("Integration | Component | select-kit/timezone-input", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.subject = selectKit();
  });

  test("errors for IST", async function (assert) {
    await render(<template><TimezoneInput /></template>);

    await this.subject.expand();
    await this.subject.fillInFilter("ist");
    await this.subject.selectRowByValue("IST");

    assert
      .dom(".select-kit-error")
      .hasText(i18n("timezone_input.ambiguous_ist"), "shows the error for IST");
  });
});
