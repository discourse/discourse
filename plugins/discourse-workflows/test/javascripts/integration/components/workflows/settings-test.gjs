import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import WorkflowSettings from "discourse/plugins/discourse-workflows/admin/components/workflows/settings";

module("Integration | Component | Workflows | Settings", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  test("submission checks show an explanation instead of execution settings", async function (assert) {
    const workflow = {
      id: 1,
      nodes: [{ type: "trigger:before_post_submission" }],
      timezone: "UTC",
    };

    await render(
      <template><WorkflowSettings @workflow={{workflow}} /></template>
    );

    assert
      .dom(".workflows-settings")
      .includesText(
        i18n("discourse_workflows.submission_check.settings_hint"),
        "the read-only check settings are explained"
      )
      .doesNotIncludeText(
        i18n("discourse_workflows.settings.error_workflow"),
        "error workflow execution is not offered"
      )
      .doesNotIncludeText(
        i18n("discourse_workflows.settings.timezone"),
        "scheduling settings are not offered"
      )
      .includesText(
        i18n("discourse_workflows.settings.danger_zone"),
        "the workflow can still be deleted"
      );
  });

  test("ordinary workflows retain execution settings", async function (assert) {
    const workflow = {
      id: 1,
      nodes: [{ type: "trigger:manual" }],
      timezone: "UTC",
    };

    await render(
      <template><WorkflowSettings @workflow={{workflow}} /></template>
    );

    assert
      .dom(".workflows-settings")
      .includesText(
        i18n("discourse_workflows.settings.error_workflow"),
        "ordinary workflows offer an error workflow"
      )
      .includesText(
        i18n("discourse_workflows.settings.timezone"),
        "ordinary workflows retain their timezone"
      );
  });
});
