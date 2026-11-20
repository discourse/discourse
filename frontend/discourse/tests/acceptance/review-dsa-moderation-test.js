import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import form from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

const modal = ".dsa-moderation-action";
const submitButton = `${modal} button[type="submit"]`;
const username = "sampleposter";
const category = "STATEMENT_CATEGORY_OTHER_VIOLATION_TC";
const communityRule = { id: "no-advertising", ground: "No advertising" };
const repliesConfirmation =
  "Are you sure you want to delete the replies to the post as well?";
const actions = [
  {
    id: "delete_user",
    label: "Delete user",
    title: "Delete @sampleposter?",
    confirmMessage: "Are you sure you want to delete @sampleposter?",
  },
  {
    id: "delete_user_block",
    label: "Delete and block user",
    title: "Delete and block @sampleposter?",
    confirmMessage: "Are you sure you want to delete and block @sampleposter?",
  },
  {
    id: "delete_and_agree_replies",
    label: "Delete post and replies",
    title: "Delete post and replies?",
    confirmMessage: repliesConfirmation,
  },
  {
    id: "delete_and_ignore_replies",
    label: "Delete post and replies, ignore flag",
    title: "Delete post and replies, ignore flag?",
    confirmMessage: repliesConfirmation,
  },
];
const pluginAction = {
  id: "plugin_remove_attachment",
  label: "Remove attachment",
  confirmMessage: "This removes the attachment from the post.",
};

async function openAction(actionId) {
  const menu = selectKit(".reviewable-action-dropdown");
  await menu.expand();
  await menu.selectRowByValue(`post-${actionId}`);
}

async function chooseCommunityRule() {
  await click(`${modal} .dsa-classification-select`);
  await click(`.dsa-classification-option[data-value="${communityRule.id}"]`);
}

acceptance("Review DSA moderation", function (needs) {
  let classificationOptions;

  needs.user({ admin: true });
  needs.settings({ reviewable_claiming: "disabled" });
  needs.hooks.beforeEach(() => {
    classificationOptions = {
      community_rules: [communityRule, { id: "be-kind", ground: "Be kind" }],
      categories: [
        { id: category, name: "Other violation of terms and conditions" },
      ],
    };
  });

  needs.pretender((server, helper) => {
    const reviewActions = [...actions, pluginAction];
    server.get("/review/1", () =>
      helper.response({
        reviewable: {
          id: 1,
          type: "ReviewableFlaggedPost",
          status: 0,
          version: 0,
          created_at: "2026-11-01T12:00:00.000Z",
          target_created_by_id: 42,
          cooked: "<p>Unsolicited advertising</p>",
          bundled_action_ids: ["1-actions"],
          reviewable_score_ids: [],
        },
        bundled_actions: [
          {
            id: "1-actions",
            label: "Actions",
            action_ids: reviewActions.map(({ id }) => `1-${id}`),
          },
        ],
        actions: reviewActions.map(({ id, label, title, confirmMessage }) => ({
          id: `1-${id}`,
          action_name: `post-${id}`,
          server_action: id,
          label,
          confirm_title: title,
          confirm_message: confirmMessage,
          confirm_destructive: true,
          dsa_classification_required: Boolean(classificationOptions),
        })),
        users: [{ id: 42, username }],
        meta: { types: { target_created_by: "user" } },
        extras: { dsa_classification: classificationOptions },
        __rest_serializer: "1",
      })
    );
  });

  test("confirms all four actions directly with their prefilled classification", async function (assert) {
    classificationOptions.community_rules = [communityRule];
    classificationOptions.default_category = category;

    await visit("/review/1");

    for (const { id, label, title, confirmMessage } of actions) {
      await openAction(id);

      assert
        .dom(`${modal} .d-modal__title-text`)
        .hasText(title, `names the target for ${label}`);
      assert.dom(`${modal} h2`).hasText("DSA classification");
      assert
        .dom(`${modal} form`)
        .isVisible(`shows classification immediately for ${label}`);
      assert
        .dom(`${modal} .d-modal__body`)
        .doesNotIncludeText(
          confirmMessage,
          "the title serves as the confirmation"
        );
      assert.dom(submitButton).hasText(label, "names the final action");
      assert.dom(submitButton).isNotDisabled("both prefilled fields count");

      await click(`${modal} .d-modal-cancel`);
    }
  });

  test("requires both classification fields and submits only after confirmation", async function (assert) {
    pretender.put("/review/1/perform/delete_user_block", (request) => {
      assert.step("delete and block user");
      assert.deepEqual(
        parsePostData(request.requestBody).dsa_classification,
        { community_rule: communityRule.id, category },
        "the moderation action includes the classification"
      );
      return response({ reviewable_perform_result: { success: true } });
    });

    await visit("/review/1");
    await openAction("delete_user_block");

    assert.dom(submitButton).isDisabled("both fields are empty");

    await form(`${modal} form`).field("category").select(category);
    assert.dom(submitButton).isDisabled("the community rule is still empty");

    await chooseCommunityRule();
    assert.dom(submitButton).isNotDisabled("both fields have values");

    await click(`${modal} .d-modal-cancel`);
    assert.dom(modal).doesNotExist("Cancel closes the dialog");
    assert.verifySteps([], "cancelling does not submit a moderation action");

    await openAction("delete_user_block");
    await chooseCommunityRule();
    assert.dom(submitButton).isDisabled("the category is still empty");

    await form(`${modal} form`).field("category").select(category);
    await click(submitButton);

    assert.verifySteps(["delete and block user"], "submits the action once");
    assert.dom(modal).doesNotExist("the dialog closes after submission");
  });

  test("uses the existing confirmation when no classification is required", async function (assert) {
    classificationOptions = undefined;

    await visit("/review/1");
    await openAction("delete_user_block");

    assert
      .dom(".dialog-container")
      .includesText(
        actions[1].confirmMessage,
        "shows the standard confirmation"
      );
    assert.dom(modal).doesNotExist("the DSA form is absent");
  });

  test("preserves custom confirmation copy alongside classification for a plugin action", async function (assert) {
    await visit("/review/1");
    await openAction(pluginAction.id);

    assert.dom(`${modal} .d-modal__title-text`).hasText(pluginAction.label);
    assert
      .dom(`${modal} .d-modal__body`)
      .includesText(pluginAction.confirmMessage);
    assert.dom(`${modal} form`).isVisible();
    assert.dom(submitButton).hasText(pluginAction.label).isDisabled();

    await click(`${modal} .d-modal-cancel`);
    assert.dom(modal).doesNotExist();
  });
});
