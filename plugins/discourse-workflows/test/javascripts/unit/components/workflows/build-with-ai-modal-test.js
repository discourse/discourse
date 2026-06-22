import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { i18n } from "discourse-i18n";
import BuildWithAiModal from "discourse/plugins/discourse-workflows/admin/components/workflows/build-with-ai-modal";

module("Unit | Component | Workflows | BuildWithAiModal", function (hooks) {
  setupTest(hooks);

  test("proposal review replaces prompt composer", function (assert) {
    const modal = Object.create(BuildWithAiModal.prototype);

    modal.aiGenerating = false;
    modal.aiResponse = {
      status: "proposed_patch",
      response: {
        message: "Draft proposal ready",
        proposal: {
          operations: [{ op: "rename_node", node_id: "node-1", name: "Wait" }],
        },
      },
    };

    assert.true(
      modal.aiShowingProposalReview,
      "proposal review is shown when a draft exists"
    );
    assert.false(
      modal.aiShowingPromptComposer,
      "prompt composer is hidden while reviewing a draft"
    );
    assert.strictEqual(
      modal.aiResponseMessage,
      null,
      "proposal response message is hidden to avoid duplicate review copy"
    );
  });

  test("proposal exposes created agent resources", function (assert) {
    const modal = Object.create(BuildWithAiModal.prototype);

    modal.aiResponse = {
      status: "proposed_patch",
      response: {
        proposal: {
          operations: [
            {
              op: "create_ai_agent",
              client_id: "triage-agent",
              agent: {
                name: "Workflow triage agent",
                description: "Classifies support posts.",
                system_prompt: "Classify Discourse posts.",
              },
            },
          ],
        },
      },
    };

    assert.deepEqual(
      modal.aiCreatedAgentResources,
      [
        {
          key: "triage-agent-Workflow triage agent",
          name: "Workflow triage agent",
          description: "Classifies support posts.",
          systemPrompt: "Classify Discourse posts.",
        },
      ],
      "created AI agents are available for proposal review"
    );
  });

  test("clarification questions advance one at a time", async function (assert) {
    const modal = Object.create(BuildWithAiModal.prototype);

    modal.aiGenerating = false;
    modal.aiClarificationQuestionIndex = 0;
    modal.aiResponse = {
      status: "needs_clarification",
      response: {
        questions: [
          { id: "scope", question: "Scope?", options: ["General"] },
          { id: "users", question: "Users?", options: ["TL2"] },
        ],
      },
    };
    Object.defineProperty(modal, "aiClarificationCurrentQuestionDisabled", {
      value: false,
    });

    assert.strictEqual(
      modal.aiCurrentQuestionNumber,
      1,
      "starts on the first question"
    );
    assert.strictEqual(
      modal.aiQuestionText(modal.aiCurrentQuestion),
      "Scope?",
      "only the first question is current"
    );
    assert.strictEqual(
      modal.aiClarificationContinueLabel,
      i18n("discourse_workflows.ai.next_question"),
      "non-final questions use a next label"
    );

    await modal.continueAiClarificationQuestion();

    assert.strictEqual(
      modal.aiCurrentQuestionNumber,
      2,
      "moves to the second question"
    );
    assert.strictEqual(
      modal.aiQuestionText(modal.aiCurrentQuestion),
      "Users?",
      "the second question becomes current"
    );

    modal.previousAiClarificationQuestion();

    assert.strictEqual(
      modal.aiCurrentQuestionNumber,
      1,
      "can move back to the previous question"
    );

    await modal.continueAiClarificationQuestion();
    Object.defineProperty(modal, "submitAiClarification", {
      value: async () => assert.step("submitted"),
    });

    assert.strictEqual(
      modal.aiClarificationContinueLabel,
      i18n("discourse_workflows.ai.continue"),
      "the final question uses the continue label"
    );

    await modal.continueAiClarificationQuestion();

    assert.verifySteps(["submitted"]);
  });

  test("progress is shown only while generating", function (assert) {
    const modal = Object.create(BuildWithAiModal.prototype);

    modal.aiProgressEvents = [{ stage: "queued" }];
    modal.aiGenerating = false;

    assert.false(
      modal.aiShowingProgress,
      "completed authoring does not show old progress"
    );

    modal.aiGenerating = true;

    assert.true(
      modal.aiShowingProgress,
      "active authoring shows progress events"
    );

    modal.aiProgressEvents = [];

    assert.false(
      modal.aiShowingProgress,
      "active authoring without events does not show progress"
    );
  });

  test("returning to the prompt clears in-progress authoring state", function (assert) {
    const modal = Object.create(BuildWithAiModal.prototype);
    const handler = () => {};

    Object.defineProperty(modal, "messageBus", {
      value: {
        unsubscribe(channel, callback) {
          assert.strictEqual(
            channel,
            "/discourse-workflows/ai-authoring/generation-1",
            "unsubscribes from the active authoring channel"
          );
          assert.strictEqual(
            callback,
            handler,
            "unsubscribes the active authoring handler"
          );
          assert.step("unsubscribed");
        },
      },
    });

    modal.aiGenerating = true;
    modal.aiProgressEvents = [{ stage: "queued" }];
    modal.aiResponse = { status: "needs_clarification" };
    modal.aiSessionId = "session-1";
    modal.aiGenerationId = "generation-1";
    modal.aiClarificationAnswers = { scope: { selected: ["General"] } };
    modal.aiClarificationQuestionIndex = 1;
    modal.aiError = "The request failed";
    modal.aiAuthoringChannel = "/discourse-workflows/ai-authoring/generation-1";
    modal.aiAuthoringHandler = handler;

    assert.true(
      modal.aiCanReturnToPrompt,
      "stateful AI authoring can return to the prompt"
    );

    modal.returnToAiPrompt();

    assert.verifySteps(["unsubscribed"]);
    assert.false(modal.aiGenerating, "generation stops locally");
    assert.deepEqual(modal.aiProgressEvents, [], "progress is cleared");
    assert.strictEqual(modal.aiResponse, null, "response is cleared");
    assert.strictEqual(modal.aiSessionId, null, "session is cleared");
    assert.strictEqual(modal.aiGenerationId, null, "generation is cleared");
    assert.deepEqual(
      modal.aiClarificationAnswers,
      {},
      "clarification answers are cleared"
    );
    assert.strictEqual(
      modal.aiClarificationQuestionIndex,
      0,
      "clarification index is reset"
    );
    assert.strictEqual(modal.aiError, null, "error state is cleared");
    assert.strictEqual(modal.aiAuthoringChannel, null, "channel is cleared");
    assert.strictEqual(modal.aiAuthoringHandler, null, "handler is cleared");
    assert.false(
      modal.aiCanReturnToPrompt,
      "cleared state no longer shows a start-over action"
    );
  });
});
