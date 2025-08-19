import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MountWidget from "discourse/components/mount-widget";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DecoratorHelper from "discourse/widgets/decorator-helper";
import PostCooked from "discourse/widgets/post-cooked";
import { createWidget } from "discourse/widgets/widget";

// TODO (glimmer-post-stream) remove this test when removing the widget post stream code
module("Integration | Component | Widget | post-cooked", function (hooks) {
  setupRenderingTest(hooks);

  test("quotes with no username and no valid topic", async function (assert) {
    const args = {
      cooked: `<aside class=\"quote no-group quote-post-not-found\" data-post=\"1\" data-topic=\"123456\">\n<blockquote>\n<p>abcd</p>\n</blockquote>\n</aside>\n<p>Testing the issue</p>`,
    };

    createWidget("test-widget", {
      html(attrs) {
        return [
          new PostCooked(attrs, new DecoratorHelper(this), this.currentUser),
        ];
      },
    });

    await render(
      <template><MountWidget @widget="test-widget" @args={{args}} /></template>
    );

    assert.dom("blockquote").hasText("abcd");
  });
});
