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
        "post_id=123&version=0",
        "sends the rendered post id with the inline action"
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
      .hasText(
        "Suspend user Approved",
        "keeps the action visible after approving"
      );
    assert
      .dom(".ai-tool-approval__details")
      .doesNotHaveAttribute("open", "details are collapsed");

    await click(".ai-tool-approval__toggle");

    assert
      .dom(".ai-tool-approval__summary")
      .includesText("Spam", "expands to reveal the approved action's reason");
  });

  test("an approved action keeps its name visible with expandable details", async function (assert) {
    updateCurrentUser({ moderator: true, admin: false });

    const approved = { ...reviewable, status: 1 };
    pretender.get("/review/42", () => response({ reviewable: approved }));

    await render(
      <template><AiToolApproval @postId="123" @reviewableId="42" /></template>
    );

    assert
      .dom(".ai-tool-approval__toggle")
      .hasText("Suspend user Approved", "shows the action and approval status");

    await click(".ai-tool-approval__toggle");

    assert
      .dom(".ai-tool-approval__summary")
      .includesText("Spam", "expands to reveal what was approved");
    assert
      .dom(".ai-tool-approval__actions")
      .doesNotExist("offers no revert action");
    assert
      .dom(".ai-tool-approval__details")
      .hasAttribute("open", "", "exposes the expanded state");

    await click(".ai-tool-approval__toggle");

    assert
      .dom(".ai-tool-approval__details")
      .doesNotHaveAttribute("open", "details can be collapsed again");
  });

  test("rejecting an action shows its name and rejected status", async function (assert) {
    updateCurrentUser({ moderator: true, admin: false });
    pretender.get("/review/42", () => response({ reviewable }));
    pretender.put("/review/42/perform/reject", () =>
      response({ reviewable_perform_result: { success: true } })
    );

    await render(
      <template><AiToolApproval @postId="123" @reviewableId="42" /></template>
    );
    await click(".ai-tool-approval__actions .btn-danger");

    assert
      .dom(".ai-tool-approval__toggle")
      .hasText("Suspend user Rejected", "identifies the rejected action");
    assert
      .dom(".ai-tool-approval__badge .d-icon-xmark")
      .exists("distinguishes rejection with an icon as well as text");
    assert
      .dom(".ai-tool-approval__actions")
      .doesNotExist("removes the approval controls");
  });

  for (const { toolName, title, parameters, detail } of [
    {
      toolName: "create_category",
      title: "Create category",
      parameters: { name: "Bugs", description: "Report bugs and issues here." },
      detail: "Report bugs and issues here.",
    },
    {
      toolName: "set_site_setting",
      title: "Set site setting",
      parameters: { setting_name: "title", value: "Our community" },
      detail: "Our community",
    },
    {
      toolName: "silence_user",
      title: "Silence user",
      parameters: { username: "noisyuser", reason: "Repeated spam" },
      detail: "@noisyuser",
    },
    {
      toolName: "custom_action",
      title: "Custom action",
      parameters: { enabled: false, count: 0, options: { groups: [1, 2] } },
      detail: '{"groups":[1,2]}',
    },
  ]) {
    test(`${toolName} uses the generic approval receipt`, async function (assert) {
      pretender.get("/review/42", () =>
        response({
          reviewable: {
            ...reviewable,
            status: 1,
            tool_name: toolName,
            tool_parameters: parameters,
          },
        })
      );

      await render(
        <template><AiToolApproval @postId="123" @reviewableId="42" /></template>
      );

      assert
        .dom(".ai-tool-approval__title")
        .hasText(title, "identifies the action without expanding");
      assert
        .dom(".ai-tool-approval__details")
        .doesNotHaveAttribute("open", "parameters are collapsed initially");

      await click(".ai-tool-approval__toggle");

      assert
        .dom(".ai-tool-approval__summary")
        .includesText(detail, "preserves the action's parameters")
        .includesText("Snorlax", "includes the agent for context");
    });
  }

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
