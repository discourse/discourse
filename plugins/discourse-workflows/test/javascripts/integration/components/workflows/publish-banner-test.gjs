import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PublishBanner from "discourse/plugins/discourse-workflows/admin/components/workflows/publish-banner";

module("Integration | Component | Workflows | PublishBanner", function (hooks) {
  setupRenderingTest(hooks);

  test("hides when the published workflow has no pending changes", async function (assert) {
    const workflow = {
      id: 1,
      activeVersionId: "published-uuid",
      hasUnpublishedChanges: false,
    };

    await render(<template><PublishBanner @workflow={{workflow}} /></template>);

    assert.dom(".workflows-publish-banner").doesNotExist();
  });

  test("shows when the published workflow has pending changes", async function (assert) {
    const workflow = {
      id: 1,
      activeVersionId: "published-uuid",
      hasUnpublishedChanges: true,
    };

    await render(<template><PublishBanner @workflow={{workflow}} /></template>);

    assert.dom(".workflows-publish-banner").exists();
    assert
      .dom(".workflows-publish-banner__title")
      .hasText("You have unpublished changes");
  });

  test("shows for a never-published workflow", async function (assert) {
    const workflow = {
      id: 1,
      activeVersionId: null,
      hasUnpublishedChanges: false,
    };

    await render(<template><PublishBanner @workflow={{workflow}} /></template>);

    assert.dom(".workflows-publish-banner").exists();
  });
});
