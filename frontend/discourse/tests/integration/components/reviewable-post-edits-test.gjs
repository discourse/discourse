import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewablePostEdits from "discourse/components/reviewable-post-edits";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | ReviewablePostEdits", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the number of edits", async function (assert) {
    const reviewable = {
      post_id: 1,
      post_version: 3,
      post_updated_at: "2026-01-01T12:00:00Z",
    };

    await render(
      <template><ReviewablePostEdits @reviewable={{reviewable}} /></template>
    );

    assert.dom(".post-info.edits .btn").hasText("2", "counts the edits");
  });

  test("renders nothing for an unedited post", async function (assert) {
    const reviewable = { post_id: 1, post_version: 1 };

    await render(
      <template><ReviewablePostEdits @reviewable={{reviewable}} /></template>
    );

    assert.dom(".post-info.edits").doesNotExist();
  });
});
