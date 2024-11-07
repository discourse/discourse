import { htmlSafe } from "@ember/template";
import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { visible } from "discourse/tests/helpers/qunit-helpers";

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

    const openButton = ".chat-message-collapser-closed";
    const closeButton = ".chat-message-collapser-opened";
    const body = ".cat";

    assert.true(visible(body));

    await click(closeButton);
    assert.false(visible(body));

    await click(openButton);
    assert.true(visible(body));
  });
});
