import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";

module("Integration | ui-kit | Helper | dEmoji", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function (assert) {
    await render(<template>{{dEmoji "tada"}}</template>);
    assert.dom(`.emoji[title="tada"]`).exists();
  });

  test("it renders custom title", async function (assert) {
    const title = "custom title";

    await render(<template>{{dEmoji "tada" title=title}}</template>);

    assert.dom(`.emoji[title="${title}"]`).exists();
  });
});
