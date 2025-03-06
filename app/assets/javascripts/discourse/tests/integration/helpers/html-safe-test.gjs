import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import htmlSafe from "discourse/helpers/html-safe";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | html-safe", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    const string = "<p class='cookies'>biscuits</p>";

    await render(<template>{{htmlSafe string}}</template>);

    assert.dom("p.cookies").exists("displays the string as html");
  });
});
