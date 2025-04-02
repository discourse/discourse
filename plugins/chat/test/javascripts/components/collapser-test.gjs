import { htmlSafe } from "@ember/template";
import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Discourse Chat | Component | collapser", function (hooks) {
  setupRenderingTest(hooks);

  test("renders header", async function (assert) {
    this.set("header", htmlSafe(`<div class="cat">tomtom</div>`));

    await render(hbs`<Collapser @header={{this.header}} />`);

    assert.dom(".cat").exists();
  });

  test("collapses and expands yielded body", async function (assert) {
    await render(hbs`
      <Collapser>
        <div class="cat">body text</div>
      </Collapser>
    `);

    assert.dom(".cat").isVisible();

    await click(".chat-message-collapser-opened");
    assert.dom(".cat").isNotVisible();

    await click(".chat-message-collapser-closed");
    assert.dom(".cat").isVisible();
  });
});
