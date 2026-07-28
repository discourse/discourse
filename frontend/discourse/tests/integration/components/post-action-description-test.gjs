import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostActionDescription from "discourse/components/post-action-description";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | PostActionDescription", function (hooks) {
  setupRenderingTest(hooks);

  test("escapes action actor names before trusting action description HTML", async function (assert) {
    this.username = '<img src=x onerror="alert(1)">';

    await render(
      <template>
        <PostActionDescription
          @actionCode="invited_user"
          @username={{this.username}}
        />
      </template>
    );

    assert
      .dom(".excerpt img")
      .doesNotExist("does not render actor name as HTML");
    assert
      .dom(".excerpt .mention")
      .hasText(`@${this.username}`, "shows the actor name as text");
  });
});
