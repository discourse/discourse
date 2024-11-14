import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | html-safe", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    this.set("string", "<p class='cookies'>biscuits</p>");

    await render(hbs`{{html-safe this.string}}`);

    assert.dom("p.cookies").exists("displays the string as html");
  });
});
