import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  logIn,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import AiToolApproval from "discourse/plugins/discourse-ai/discourse/components/ai-tool-approval";

module("Integration | Component | AiToolApproval", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    logIn(getOwner(this));
  });

  const reviewable = {
    id: 42,
    version: 0,
    status: 0,
    tool_name: "suspend_user",
    tool_parameters: { username: "baduser", duration_days: 7, reason: "Spam" },
    payload: { agent_name: "Snorlax" },
  };

  test("staff can review and approve a pending action", async function (assert) {
    updateCurrentUser({ moderator: true, admin: false });

    pretender.get("/review/42", () => response({ reviewable }));
    pretender.put("/review/42/perform/approve", (request) => {
      assert.strictEqual(
        request.requestBody,
        "version=0",
        "sends the reviewable version with the approval action"
      );

      return response({ reviewable_perform_result: { success: true } });
    });

    await render(
      <template><AiToolApproval @postId="123" @reviewableId="42" /></template>
    );

    assert.dom(".ai-tool-approval__value").exists("shows the tool's details");
    assert
      .dom(".ai-tool-approval__actions .btn-primary")
      .exists("shows the approve button to staff");

    await click(".ai-tool-approval__actions .btn-primary");

    assert
      .dom(".ai-tool-approval__toggle")
      .hasText("Approved", "collapses to a status toggle after approving");
    assert
      .dom(".ai-tool-approval__summary")
      .doesNotExist("hides the details once resolved");

    await click(".ai-tool-approval__toggle");

    assert
      .dom(".ai-tool-approval__summary")
      .includesText("Spam", "expands to reveal the approved action's reason");
  });

  test("an approved action collapses to an expandable status with no revert action", async function (assert) {
    updateCurrentUser({ moderator: true, admin: false });

    const approved = { ...reviewable, status: 1 };
    pretender.get("/review/42", () => response({ reviewable: approved }));

    await render(
      <template><AiToolApproval @postId="123" @reviewableId="42" /></template>
    );

    assert
      .dom(".ai-tool-approval__toggle")
      .hasText("Approved", "shows the collapsed approved state");

    await click(".ai-tool-approval__toggle");

    assert
      .dom(".ai-tool-approval__summary")
      .includesText("Spam", "expands to reveal what was approved");
    assert
      .dom(".ai-tool-approval__actions")
      .doesNotExist("offers no revert action");
  });

  test("non-staff sees a pending message without action buttons", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    pretender.get("/review/42", () => response({ reviewable }));

    await render(
      <template><AiToolApproval @postId="123" @reviewableId="42" /></template>
    );

    assert
      .dom(".ai-tool-approval__actions")
      .doesNotExist("hides the action buttons");
    assert
      .dom(".ai-tool-approval__status")
      .exists("shows an awaiting-approval message");
  });

  test("a 403 from the review endpoint shows the awaiting-approval message, not an error", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    pretender.get("/review/42", () => response(403, {}));

    await render(
      <template><AiToolApproval @postId="123" @reviewableId="42" /></template>
    );

    assert
      .dom(".ai-tool-approval__status")
      .hasText(
        i18n("discourse_ai.ai_tool_approval.awaiting_staff"),
        "shows awaiting approval instead of a load error"
      );
  });
});
