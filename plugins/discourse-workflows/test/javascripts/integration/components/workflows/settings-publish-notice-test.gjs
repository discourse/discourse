import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import SettingsPublishNotice from "discourse/plugins/discourse-workflows/admin/components/workflows/settings-publish-notice";

module(
  "Integration | Component | Workflows | SettingsPublishNotice",
  function (hooks) {
    setupRenderingTest(hooks);

    test("hides when the published workflow has no pending changes", async function (assert) {
      const workflow = {
        id: 1,
        activeVersionId: "published-uuid",
        hasUnpublishedChanges: false,
      };

      await render(
        <template><SettingsPublishNotice @workflow={{workflow}} /></template>
      );

      assert.dom(".workflows-settings-publish-notice").doesNotExist();
    });

    test("shows when the published workflow has pending changes", async function (assert) {
      const workflow = {
        id: 1,
        activeVersionId: "published-uuid",
        hasUnpublishedChanges: true,
      };

      await render(
        <template><SettingsPublishNotice @workflow={{workflow}} /></template>
      );

      assert.dom(".workflows-settings-publish-notice").exists();
      assert
        .dom(".workflows-settings-publish-notice__title")
        .hasText("You have unpublished changes");
    });

    test("shows for a never-published workflow", async function (assert) {
      const workflow = {
        id: 1,
        activeVersionId: null,
        hasUnpublishedChanges: false,
      };

      await render(
        <template><SettingsPublishNotice @workflow={{workflow}} /></template>
      );

      assert.dom(".workflows-settings-publish-notice").exists();
    });

    test("publish failure surfaces an error and leaves the workflow's state untouched", async function (assert) {
      pretender.put("/admin/plugins/discourse-workflows/workflows/1.json", () =>
        response(422, { errors: ["Something went wrong"] })
      );

      const workflow = {
        id: 1,
        versionId: "draft-uuid",
        activeVersionId: "published-uuid",
        hasUnpublishedChanges: true,
      };

      let alertedWith;
      this.owner.lookup("service:dialog").alert = (message) =>
        (alertedWith = message);

      await render(
        <template><SettingsPublishNotice @workflow={{workflow}} /></template>
      );

      await click(".workflows-settings-publish-notice__btn.btn-primary");

      assert.true(
        String(alertedWith).includes("Something went wrong"),
        "the error is surfaced to the admin"
      );
      assert.strictEqual(
        workflow.activeVersionId,
        "published-uuid",
        "the workflow's active version is unchanged"
      );
      assert.true(
        workflow.hasUnpublishedChanges,
        "the workflow still has unpublished changes"
      );
      assert
        .dom(".workflows-settings-publish-notice")
        .exists("the notice is still shown, not stuck hidden");
    });
  }
);
