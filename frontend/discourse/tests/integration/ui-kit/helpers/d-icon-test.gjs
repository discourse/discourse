import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dIcon from "discourse/ui-kit/helpers/d-icon";

module("Integration | ui-kit | Helper | dIcon", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    await render(
      <template>
        <div class="test">{{dIcon "bars"}}</div>
      </template>
    );

    assert
      .dom(".test")
      .hasHtml(
        '<svg class="fa d-icon d-icon-bars svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#bars"></use></svg>'
      );
  });

  test("with replacement", async function (assert) {
    await render(
      <template>
        <div class="test">{{dIcon "d-watching"}}</div>
      </template>
    );

    assert
      .dom(".test")
      .hasHtml(
        '<svg class="fa d-icon d-icon-d-watching svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#discourse-bell-exclamation"></use></svg>'
      );
  });
});
