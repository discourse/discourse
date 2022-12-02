import { module, test } from "qunit";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { click, render, settled } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { hbs } from "ember-cli-htmlbars";

module("Unit | Utility | ajax errors", function (hooks) {
  setupRenderingTest(hooks);
  hooks.beforeEach(async function () {
    await render(hbs`<DialogHolder />`);
  });

  hooks.afterEach(async function () {
    await click(".dialog-footer .btn-primary");
  });

  test("popupAjaxError", async function (assert) {
    const message = "here is the error message";
    const error = {
      jqXHR: {
        status: 422,
        responseJSON: { message },
      },
    };

    await popupAjaxError(error);
    await settled();

    assert.strictEqual(
      document.querySelector(".dialog-body").textContent.trim(),
      message
    );
  });

  test("popupAjaxError with HTML", async function (assert) {
    const error = {
      jqXHR: {
        status: 422,
        responseJSON: { message: "here is a <b>special</b> error message" },
      },
    };

    await popupAjaxError(error, { htmlMessage: true });
    await settled();

    assert.strictEqual(
      document.querySelector(".dialog-body b").textContent.trim(),
      "special"
    );
  });
});
