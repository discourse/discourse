import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dBoundAvatar from "discourse/ui-kit/helpers/d-bound-avatar";

module("Integration | ui-kit | Helper | dBoundAvatar", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a placeholder without a user", async function (assert) {
    await render(<template>{{dBoundAvatar null "tiny"}}</template>);

    assert.dom(".avatar-placeholder").exists();
    assert.dom("img.avatar").doesNotExist();
  });

  test("renders the user's avatar at the size", async function (assert) {
    const user = { avatar_template: "/avatar/{size}.png" };

    await render(<template>{{dBoundAvatar user "tiny"}}</template>);

    assert
      .dom("img.avatar")
      .hasAttribute("src", /\/avatar\/\d+\.png$/)
      .hasAttribute("width", "24");
  });
});
