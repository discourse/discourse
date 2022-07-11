import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | html-safe-helper", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    this.set("string", "<p class='cookies'>biscuits</p>");

    await render(hbs`{{html-safe string}}`);

    assert.ok(exists("p.cookies"), "it displays the string as html");
  });
});
