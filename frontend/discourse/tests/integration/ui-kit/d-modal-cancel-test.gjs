import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";

const noop = () => {};

module("Integration | ui-kit | DModalCancel", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a flat cancel button", async function (assert) {
    await render(<template><DModalCancel @close={{noop}} /></template>);

    assert
      .dom(".d-modal-cancel")
      .hasClass("btn-flat", "the button is flat")
      .hasText(i18n("cancel"), "the button is labelled Cancel");
  });

  test("calls @close on click", async function (assert) {
    let closed = 0;
    const close = () => closed++;

    await render(<template><DModalCancel @close={{close}} /></template>);
    await click(".d-modal-cancel");

    assert.strictEqual(closed, 1, "@close is called once");
  });
});
