import { htmlSafe } from "@ember/template";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Collapser from "discourse/plugins/chat/discourse/components/collapser";

module("Discourse Chat | Component | collapser", function (hooks) {
  setupRenderingTest(hooks);

  test("renders header", async function (assert) {
    const self = this;

    this.set("header", htmlSafe(`<div class="cat">tomtom</div>`));

    await render(<template><Collapser @header={{self.header}} /></template>);

    assert.dom(".cat").exists();
  });

  test("collapses and expands yielded body", async function (assert) {
    await render(
      <template>
        <Collapser>
          <div class="cat">body text</div>
        </Collapser>
      </template>
    );

    assert.dom(".cat").isVisible();

    await click(".chat-message-collapser-opened");
    assert.dom(".cat").isNotVisible();

    await click(".chat-message-collapser-closed");
    assert.dom(".cat").isVisible();
  });
});
