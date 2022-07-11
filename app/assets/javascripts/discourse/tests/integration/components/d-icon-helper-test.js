import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | d-icon helper", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    await render(hbs`<div class="test">{{d-icon "bars"}}</div>`);

    const html = query(".test").innerHTML.trim();
    assert.strictEqual(
      html,
      '<svg class="fa d-icon d-icon-bars svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#bars"></use></svg>'
    );
  });

  test("with replacement", async function (assert) {
    await render(hbs`<div class="test">{{d-icon "d-watching"}}</div>`);

    const html = query(".test").innerHTML.trim();
    assert.strictEqual(
      html,
      '<svg class="fa d-icon d-icon-d-watching svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#discourse-bell-exclamation"></use></svg>'
    );
  });
});
