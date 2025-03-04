import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import emoji from "discourse/helpers/emoji";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | emoji", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function (assert) {
    await render(<template>{{emoji "tada"}}</template>);
    assert.dom(`.emoji[title="tada"]`).exists();
  });

  test("it renders custom title", async function (assert) {const self = this;

    const title = "custom title";
    this.set("title", title);

    await render(<template>{{emoji "tada" title=self.title}}</template>);

    assert.dom(`.emoji[title="${title}"]`).exists();
  });
});
