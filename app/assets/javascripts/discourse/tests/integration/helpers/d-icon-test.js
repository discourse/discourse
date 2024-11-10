import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | d-icon", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    await render(hbs`<div class="test">{{d-icon "bars"}}</div>`);

    assert
      .dom(".test")
      .hasHtml(
        '<svg class="fa d-icon d-icon-bars svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#bars"></use></svg>'
      );
  });

  test("with replacement", async function (assert) {
    await render(hbs`<div class="test">{{d-icon "d-watching"}}</div>`);

    assert
      .dom(".test")
      .hasHtml(
        '<svg class="fa d-icon d-icon-d-watching svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#discourse-bell-exclamation"></use></svg>'
      );
  });
});
