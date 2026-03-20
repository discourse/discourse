import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DEmptyState from "discourse/ui-kit/d-empty-state";

module("Integration | ui-kit | DEmptyState", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function (assert) {
    await render(
      <template>
        <DEmptyState @title="user.no_bookmarks_title" @body="body" />
      </template>
    );

    assert.dom("[data-test-title]").exists();
    assert.dom("[data-test-body]").exists();
  });
});
