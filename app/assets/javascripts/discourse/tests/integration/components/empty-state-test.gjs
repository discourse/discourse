import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import EmptyState from "discourse/components/empty-state";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | empty-state", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function (assert) {
    await render(
      <template><EmptyState @title="user.no_bookmarks_title" @body="Test body" /></template>
    );

    assert.dom("[data-test-title]").exists();
    assert.dom("[data-test-body]").hasText("Test body");
  });
});
