import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | Widget | post-cooked", function (hooks) {
  setupRenderingTest(hooks);

  test("quotes with no username and no valid topic", async function (assert) {
    this.set("args", {
      cooked: `<aside class=\"quote no-group quote-post-not-found\" data-post=\"1\" data-topic=\"123456\">\n<blockquote>\n<p>abcd</p>\n</blockquote>\n</aside>\n<p>Testing the issue</p>`,
    });

    await render(
      hbs`<MountWidget @widget="post-cooked" @args={{this.args}} />`
    );

    assert.strictEqual(query("blockquote").innerText, "abcd");
  });
});
