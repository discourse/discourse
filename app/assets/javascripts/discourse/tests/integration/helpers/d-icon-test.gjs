import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import icon from "discourse/helpers/d-icon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | d-icon", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    await render(
      <template>
        <div class="test">{{icon "bars"}}</div>
      </template>
    );

    assert
      .dom(".test")
      .hasHtml(
        '<svg class="fa d-icon d-icon-bars svg-icon svg-string" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#bars"></use></svg>'
      );
  });

  test("with replacement", async function (assert) {
    await render(
      <template>
        <div class="test">{{icon "d-watching"}}</div>
      </template>
    );

    assert
      .dom(".test")
      .hasHtml(
        '<svg class="fa d-icon d-icon-d-watching svg-icon svg-string" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#discourse-bell-exclamation"></use></svg>'
      );
  });
});
