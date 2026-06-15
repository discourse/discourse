import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import DTextarea from "discourse/ui-kit/d-textarea";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class BuildWithAiModal extends Component {
  @service messageBus;
  @service toasts;

  @tracked aiPrompt = "";
  @tracked aiGenerating = false;
  @tracked aiProgressEvents = [];
  @tracked aiResponse = null;
  @tracked aiSessionId = null;
  @tracked aiGenerationId = null;
  @tracked aiClarificationAnswers = {};
  @tracked aiClarificationQuestionIndex = 0;
  @tracked aiError = null;

  willDestroy() {
    super.willDestroy();
    this.unsubscribeFromAiAuthoring();
  }

  get aiSubmitDisabled() {
    return this.aiGenerating || !this.aiPrompt.trim();
  }

  get aiProposal() {
    if (this.aiResponseStatus !== "proposed_patch") {
      return null;
    }

    const proposal = this.aiResponse?.response?.proposal;
    return proposal?.operations?.length ? proposal : null;
  }

  get aiResponseMessage() {
    if (
      ["error", "needs_clarification"].includes(this.aiResponseStatus) ||
      this.aiProposal
    ) {
      return null;
    }

    return this.aiResponse?.response?.message;
  }

  get aiResponseStatus() {
    return this.aiResponse?.status;
  }

  get aiNeedsClarification() {
    return this.aiResponseStatus === "needs_clarification";
  }

  get aiResponseError() {
    return (
      this.aiError ||
      this.aiResponse?.error ||
      this.aiResponse?.response?.error ||
      (this.aiResponseStatus === "error"
        ? this.aiResponse?.response?.message
        : null)
    );
  }

  get aiStatusLabel() {
    if (this.aiGenerating) {
      return i18n("discourse_workflows.ai.status_working");
    }

    if (this.aiResponseError || this.aiNeedsClarification) {
      return i18n("discourse_workflows.ai.status_error");
    }

    if (this.aiProposal) {
      return i18n("discourse_workflows.ai.status_ready");
    }

    return i18n("discourse_workflows.ai.status_idle");
  }

  get aiStatusClass() {
    if (this.aiGenerating) {
      return "is-working";
    }

    if (this.aiResponseError || this.aiNeedsClarification) {
      return "is-error";
    }

    if (this.aiProposal) {
      return "is-ready";
    }

    return "is-idle";
  }

  get aiQuestions() {
    return this.aiResponse?.response?.questions || [];
  }

  get aiShowingClarification() {
    return this.aiNeedsClarification && this.aiQuestions.length;
  }

  get aiCurrentQuestionIndex() {
    return Math.min(
      this.aiClarificationQuestionIndex,
      Math.max(this.aiQuestions.length - 1, 0)
    );
  }

  get aiCurrentQuestion() {
    return this.aiQuestions[this.aiCurrentQuestionIndex];
  }

  get aiCurrentQuestionNumber() {
    return this.aiCurrentQuestionIndex + 1;
  }

  get aiFirstClarificationQuestion() {
    return this.aiCurrentQuestionIndex === 0;
  }

  get aiLastClarificationQuestion() {
    return this.aiCurrentQuestionIndex >= this.aiQuestions.length - 1;
  }

  get aiClarificationContinueLabel() {
    return this.aiLastClarificationQuestion
      ? i18n("discourse_workflows.ai.continue")
      : i18n("discourse_workflows.ai.next_question");
  }

  get aiClarificationCurrentQuestionDisabled() {
    if (this.aiGenerating || !this.aiCurrentQuestion) {
      return true;
    }

    const answer = this.#aiClarificationAnswer(
      this.aiCurrentQuestion,
      this.aiCurrentQuestionIndex
    );
    return !answer.selected.length && !answer.custom.trim();
  }

  get aiShowingProposalReview() {
    return Boolean(this.aiProposal);
  }

  get aiShowingPromptComposer() {
    return !this.aiShowingClarification && !this.aiShowingProposalReview;
  }

  get aiCanReturnToPrompt() {
    return Boolean(
      this.aiResponse ||
      this.aiError ||
      this.aiSessionId ||
      this.aiGenerationId ||
      this.aiProgressEvents?.length ||
      Object.keys(this.aiClarificationAnswers || {}).length ||
      this.aiClarificationQuestionIndex
    );
  }

  get aiNeedsClarificationFallback() {
    return this.aiNeedsClarification && !this.aiShowingClarification;
  }

  get aiClarificationSubmitDisabled() {
    return (
      this.aiGenerating ||
      !this.aiQuestions.every((question, index) => {
        const answer = this.#aiClarificationAnswer(question, index);
        return answer.selected.length || answer.custom.trim();
      })
    );
  }

  @action
  aiQuestionText(question) {
    if (typeof question === "string") {
      return question;
    }

    return question?.question || question?.text || question?.label || "";
  }

  @action
  aiQuestionOptions(question) {
    if (!question || typeof question === "string") {
      return [];
    }

    return question.options || [];
  }

  @action
  aiQuestionHasOptions(question) {
    return this.aiQuestionOptions(question).length > 0;
  }

  @action
  aiQuestionMultiSelect(question) {
    return Boolean(question?.multi_select || question?.multiSelect);
  }

  @action
  aiQuestionCustomAllowed(question) {
    return question?.custom_allowed ?? question?.customAllowed ?? true;
  }

  @action
  aiClarificationOptionLabel(option) {
    return typeof option === "string"
      ? option
      : option?.label || option?.value || "";
  }

  @action
  aiClarificationOptionDescription(option) {
    return typeof option === "string" ? "" : option?.description || "";
  }

  @action
  aiClarificationOptionSelected(question, index, option) {
    return this.#aiClarificationAnswer(question, index).selected.includes(
      this.aiClarificationOptionLabel(option)
    );
  }

  @action
  aiClarificationCustomValue(question, index) {
    return this.#aiClarificationAnswer(question, index).custom;
  }

  get aiCodePreviews() {
    return (this.aiProposal?.operations || [])
      .map((operation, index) =>
        this.#codePreviewForOperation(operation, index)
      )
      .filter(Boolean);
  }

  get aiCreatedAgentResources() {
    const resources = this.aiProposal?.created_resources || [];
    const resourcesByClientId = new Map(
      resources
        .filter(
          (resource) => resource?.type === "ai_agent" && resource.client_id
        )
        .map((resource) => [resource.client_id, resource])
    );

    return (this.aiProposal?.operations || [])
      .filter((operation) => operation?.op === "create_ai_agent")
      .map((operation, index) => {
        const agent = operation.agent || operation.ai_agent || {};
        const resource = resourcesByClientId.get(operation.client_id) || {};
        const name = resource.name || agent.name;

        if (!name) {
          return null;
        }

        return {
          key: `${operation.client_id || index}-${name}`,
          name,
          description: resource.description || agent.description,
          systemPrompt: resource.system_prompt || agent.system_prompt,
        };
      })
      .filter(Boolean);
  }

  get aiShowingProgress() {
    return this.aiGenerating && this.aiProgressEvents.length > 0;
  }

  aiProgressMessage(event) {
    return (
      event.message || i18n(`discourse_workflows.ai.progress.${event.stage}`)
    );
  }

  #codePreviewForOperation(operation, index) {
    if (
      operation?.op === "add_node" &&
      operation.node?.type === "action:code"
    ) {
      return this.#buildCodePreview(
        index,
        operation.node.name,
        operation.node.parameters || {}
      );
    }

    if (
      operation?.op === "update_node_parameters" &&
      Object.prototype.hasOwnProperty.call(operation.parameters || {}, "code")
    ) {
      return this.#buildCodePreview(
        index,
        operation.node_name || operation.node_id,
        operation.parameters || {}
      );
    }
  }

  #buildCodePreview(operationIndex, nodeName, parameters) {
    return {
      key: `${operationIndex}-${nodeName || "code"}`,
      nodeName: nodeName || i18n("discourse_workflows.ai.code_node"),
      mode: parameters.mode || "runOnceForAllItems",
      code: parameters.code || "",
      validation: this.#scriptValidationFor(operationIndex, nodeName),
    };
  }

  #scriptValidationFor(operationIndex, nodeName) {
    return (this.aiProposal?.script_validations || []).find((validation) => {
      const validationOperationIndex =
        validation.operation_index ?? validation.operationIndex;
      const validationNodeName = validation.node_name ?? validation.nodeName;
      return (
        validationOperationIndex === operationIndex ||
        (nodeName && validationNodeName === nodeName)
      );
    });
  }

  #ajaxErrorMessage(error) {
    const status = error?.jqXHR?.status ?? error?.status;
    if (status >= 500) {
      return i18n("discourse_workflows.ai.unexpected_error");
    }

    return (
      error?.jqXHR?.responseJSON?.errors?.join("\n") ||
      error?.jqXHR?.responseJSON?.error ||
      error?.jqXHR?.responseText ||
      i18n("discourse_workflows.ai.unexpected_error")
    );
  }

  #aiClarificationKey(question, index) {
    return (
      question?.id ||
      question?.key ||
      this.aiQuestionText(question) ||
      index
    )
      .toString()
      .trim();
  }

  #aiClarificationAnswer(question, index) {
    const key = this.#aiClarificationKey(question, index);
    const answer = this.aiClarificationAnswers[key] || {};

    return {
      selected: answer.selected || [],
      custom: answer.custom || "",
    };
  }

  #setAiClarificationAnswer(question, index, answer) {
    this.aiClarificationAnswers = {
      ...this.aiClarificationAnswers,
      [this.#aiClarificationKey(question, index)]: answer,
    };
  }

  #aiClarificationPayload() {
    return {
      type: "workflow_ask_questions_result",
      answers: this.aiQuestions.map((question, index) => {
        const answer = this.#aiClarificationAnswer(question, index);

        return {
          id: this.#aiClarificationKey(question, index),
          question: this.aiQuestionText(question),
          selected_options: answer.selected,
          custom_answer: answer.custom.trim(),
        };
      }),
    };
  }

  #aiClarificationMessage() {
    return JSON.stringify(this.#aiClarificationPayload());
  }

  async #submitAiMessage(message) {
    this.unsubscribeFromAiAuthoring();
    this.aiGenerating = true;
    this.aiProgressEvents = [
      {
        status: "progress",
        stage: "queued",
        message: i18n("discourse_workflows.ai.progress.queued"),
      },
    ];
    this.aiResponse = null;
    this.aiClarificationAnswers = {};
    this.aiClarificationQuestionIndex = 0;
    this.aiError = null;

    try {
      const response = await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflowId}/ai/author.json`,
        {
          type: "POST",
          data: {
            session_id: this.aiSessionId || undefined,
            message,
            mode: "edit",
          },
        }
      );

      this.aiSessionId = response.session_id;
      this.aiGenerationId = response.generation_id;
      this.#subscribeToAiAuthoring(response.generation_id);
    } catch (error) {
      this.aiGenerating = false;
      this.aiProgressEvents = [];
      this.aiError = this.#ajaxErrorMessage(error);
    }
  }

  @action
  updateAiPrompt(event) {
    this.aiPrompt = event.target.value;
  }

  @action
  returnToAiPrompt() {
    this.unsubscribeFromAiAuthoring();
    this.aiGenerating = false;
    this.aiProgressEvents = [];
    this.aiResponse = null;
    this.aiSessionId = null;
    this.aiGenerationId = null;
    this.aiClarificationAnswers = {};
    this.aiClarificationQuestionIndex = 0;
    this.aiError = null;
  }

  @action
  async submitAiPrompt() {
    if (this.aiSubmitDisabled) {
      return;
    }

    await this.#submitAiMessage(this.aiPrompt.trim());
  }

  @action
  selectAiClarificationOption(question, index, option) {
    const label = this.aiClarificationOptionLabel(option);
    if (!label) {
      return;
    }

    const answer = this.#aiClarificationAnswer(question, index);
    let selected;

    if (this.aiQuestionMultiSelect(question)) {
      selected = answer.selected.includes(label)
        ? answer.selected.filter((value) => value !== label)
        : [...answer.selected, label];
    } else {
      selected = [label];
    }

    this.#setAiClarificationAnswer(question, index, {
      ...answer,
      selected,
    });
  }

  @action
  updateAiClarificationCustom(question, index, event) {
    const answer = this.#aiClarificationAnswer(question, index);

    this.#setAiClarificationAnswer(question, index, {
      ...answer,
      custom: event.target.value,
    });
  }

  @action
  previousAiClarificationQuestion() {
    if (this.aiGenerating) {
      return;
    }

    this.aiClarificationQuestionIndex = Math.max(
      this.aiCurrentQuestionIndex - 1,
      0
    );
  }

  @action
  async continueAiClarificationQuestion() {
    if (this.aiClarificationCurrentQuestionDisabled) {
      return;
    }

    if (this.aiLastClarificationQuestion) {
      await this.submitAiClarification();
      return;
    }

    this.aiClarificationQuestionIndex = this.aiCurrentQuestionIndex + 1;
  }

  @action
  async submitAiClarification() {
    if (this.aiClarificationSubmitDisabled) {
      return;
    }

    await this.#submitAiMessage(this.#aiClarificationMessage());
  }

  @action
  async applyAiProposal() {
    if (!this.aiSessionId || !this.aiProposal) {
      return;
    }

    try {
      const response = await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflowId}/ai/apply.json`,
        {
          type: "POST",
          data: {
            session_id: this.aiSessionId,
          },
        }
      );
      this.args.onApply?.(response.workflow);
      this.returnToAiPrompt();
      this.aiPrompt = "";
      this.args.onClose?.();
      this.toasts.success({
        data: { message: i18n("discourse_workflows.ai.applied") },
      });
    } catch (error) {
      this.aiError = this.#ajaxErrorMessage(error);
    }
  }

  #subscribeToAiAuthoring(generationId) {
    const channel = `/discourse-workflows/ai-authoring/${generationId}`;
    const handler = (message) => {
      if (message.generation_id !== generationId) {
        return;
      }

      if (message.status === "progress") {
        this.aiProgressEvents = [...this.aiProgressEvents, message];
        return;
      }

      this.aiGenerating = false;
      this.aiProgressEvents = [];
      this.aiResponse = message;
      if (message.status === "needs_clarification") {
        this.aiClarificationAnswers = {};
        this.aiClarificationQuestionIndex = 0;
      }
      this.aiError = message.status === "error" ? message.error : null;
      this.unsubscribeFromAiAuthoring();
    };

    this.aiAuthoringChannel = channel;
    this.aiAuthoringHandler = handler;
    this.messageBus.subscribe(channel, handler, -1);
  }

  unsubscribeFromAiAuthoring() {
    if (this.aiAuthoringChannel && this.aiAuthoringHandler) {
      this.messageBus.unsubscribe(
        this.aiAuthoringChannel,
        this.aiAuthoringHandler
      );
    }
    this.aiAuthoringChannel = null;
    this.aiAuthoringHandler = null;
  }

  <template>
    {{#if @open}}
      <div class="workflows-canvas__ai-panel-shell">
        {{#if this.aiShowingProgress}}
          <aside
            class="workflows-canvas__ai-progress-panel"
            aria-label={{i18n "discourse_workflows.ai.progress_title"}}
          >
            <h4 class="workflows-canvas__ai-progress-title">
              {{i18n "discourse_workflows.ai.progress_title"}}
            </h4>
            <ol
              class={{dConcatClass
                "workflows-canvas__ai-progress"
                (if this.aiGenerating "is-working")
              }}
            >
              {{#each this.aiProgressEvents as |event|}}
                <li>
                  <span class="workflows-canvas__ai-progress-marker"></span>
                  <span>{{this.aiProgressMessage event}}</span>
                </li>
              {{/each}}
            </ol>
          </aside>
        {{/if}}

        <aside
          class={{dConcatClass
            "workflows-canvas__ai-panel"
            (if this.aiShowingProposalReview "is-reviewing")
          }}
          role="dialog"
          aria-labelledby="workflow-ai-panel-title"
        >
          <div class="workflows-canvas__ai-panel-header">
            <div class="workflows-canvas__ai-title-row">
              <div class="workflows-canvas__ai-title">
                <h3 id="workflow-ai-panel-title">
                  {{i18n "discourse_workflows.ai.title"}}
                </h3>
                <span
                  class={{dConcatClass
                    "workflows-canvas__ai-status"
                    this.aiStatusClass
                  }}
                >
                  {{this.aiStatusLabel}}
                </span>

              </div>
              <p>{{i18n "discourse_workflows.ai.subtitle"}}</p>
            </div>
            <DButton
              @action={{@onClose}}
              @icon="xmark"
              @title="discourse_workflows.ai.close"
              class="btn-transparent workflows-canvas__ai-close"
            />
          </div>

          {{#if this.aiShowingClarification}}
            <div class="workflows-canvas__ai-clarification">
              <div class="workflows-canvas__ai-clarification-header">
                <h4>{{i18n "discourse_workflows.ai.questions"}}</h4>
                <p>{{i18n "discourse_workflows.ai.clarification_intro"}}</p>
                <div class="workflows-canvas__ai-question-progress">
                  <span>
                    {{i18n
                      "discourse_workflows.ai.question_progress"
                      current=this.aiCurrentQuestionNumber
                      total=this.aiQuestions.length
                    }}
                  </span>
                  <progress
                    class="workflows-canvas__ai-question-progress-bar"
                    value={{this.aiCurrentQuestionNumber}}
                    max={{this.aiQuestions.length}}
                  ></progress>
                </div>
              </div>

              {{#let
                this.aiCurrentQuestion this.aiCurrentQuestionIndex
                as |question index|
              }}
                <section class="workflows-canvas__ai-question-card">
                  <h5>{{this.aiQuestionText question}}</h5>

                  {{#if (this.aiQuestionHasOptions question)}}
                    <div class="workflows-canvas__ai-question-options">
                      {{#each (this.aiQuestionOptions question) as |option|}}
                        <button
                          type="button"
                          aria-pressed={{this.aiClarificationOptionSelected
                            question
                            index
                            option
                          }}
                          class={{dConcatClass
                            "workflows-canvas__ai-question-option"
                            (if
                              (this.aiClarificationOptionSelected
                                question index option
                              )
                              "is-selected"
                            )
                          }}
                          {{on
                            "click"
                            (fn
                              this.selectAiClarificationOption
                              question
                              index
                              option
                            )
                          }}
                        >
                          <span>{{this.aiClarificationOptionLabel
                              option
                            }}</span>
                          {{#if (this.aiClarificationOptionDescription option)}}
                            <small>{{this.aiClarificationOptionDescription
                                option
                              }}</small>
                          {{/if}}
                        </button>
                      {{/each}}
                    </div>
                  {{/if}}

                  {{#if (this.aiQuestionCustomAllowed question)}}
                    <label class="workflows-canvas__ai-custom-answer">
                      <span>{{i18n
                          "discourse_workflows.ai.custom_answer"
                        }}</span>
                      <DTextarea
                        @value={{this.aiClarificationCustomValue
                          question
                          index
                        }}
                        {{on
                          "input"
                          (fn this.updateAiClarificationCustom question index)
                        }}
                        placeholder={{i18n
                          "discourse_workflows.ai.custom_answer_placeholder"
                        }}
                        disabled={{this.aiGenerating}}
                        class="workflows-canvas__ai-custom-answer-input"
                      />
                    </label>
                  {{/if}}
                </section>
              {{/let}}

              <div class="workflows-canvas__ai-panel-actions">
                <DButton
                  @action={{this.returnToAiPrompt}}
                  @translatedLabel={{i18n "discourse_workflows.ai.start_over"}}
                  @disabled={{this.aiGenerating}}
                  class="btn-default workflows-canvas__ai-start-over-btn"
                />

                {{#unless this.aiFirstClarificationQuestion}}
                  <DButton
                    @action={{this.previousAiClarificationQuestion}}
                    @icon="arrow-left"
                    @translatedLabel={{i18n
                      "discourse_workflows.ai.previous_question"
                    }}
                    @disabled={{this.aiGenerating}}
                    class="btn-default"
                  />
                {{/unless}}

                <DButton
                  @action={{this.continueAiClarificationQuestion}}
                  @translatedLabel={{this.aiClarificationContinueLabel}}
                  @isLoading={{this.aiGenerating}}
                  @disabled={{this.aiClarificationCurrentQuestionDisabled}}
                  class="btn-primary"
                />
              </div>
            </div>
          {{else if this.aiShowingProposalReview}}
            <div class="workflows-canvas__ai-review-step">
              <div class="workflows-canvas__ai-review-actions">
                <DButton
                  @action={{this.returnToAiPrompt}}
                  @icon="arrow-left"
                  @translatedLabel={{i18n
                    "discourse_workflows.ai.back_to_prompt"
                  }}
                  class="btn-transparent"
                />
              </div>

              <div class="workflows-canvas__ai-proposal">
                <h4>{{this.aiProposal.title}}</h4>
                <p>{{this.aiProposal.summary}}</p>

                {{#if this.aiCreatedAgentResources.length}}
                  <section class="workflows-canvas__ai-created-agents">
                    <h5>{{i18n "discourse_workflows.ai.created_agents"}}</h5>
                    <ul>
                      {{#each this.aiCreatedAgentResources as |agent|}}
                        <li class="workflows-canvas__ai-created-agent">
                          <strong>{{agent.name}}</strong>
                          {{#if agent.description}}
                            <p>{{agent.description}}</p>
                          {{/if}}
                          {{#if agent.systemPrompt}}
                            <details>
                              <summary>{{i18n
                                  "discourse_workflows.ai.created_agent_system_prompt"
                                }}</summary>
                              <pre><code>{{agent.systemPrompt}}</code></pre>
                            </details>
                          {{/if}}
                        </li>
                      {{/each}}
                    </ul>
                  </section>
                {{/if}}

                {{#if this.aiCodePreviews.length}}
                  <div class="workflows-canvas__ai-code-previews">
                    <h5>{{i18n "discourse_workflows.ai.script_preview"}}</h5>
                    {{#each this.aiCodePreviews as |preview|}}
                      <section class="workflows-canvas__ai-code-preview">
                        <div class="workflows-canvas__ai-code-preview-header">
                          <span>{{preview.nodeName}}</span>
                          <span>{{i18n
                              "discourse_workflows.ai.script_mode"
                              mode=preview.mode
                            }}</span>
                        </div>
                        <pre><code>{{preview.code}}</code></pre>
                        {{#if preview.validation}}
                          {{#if preview.validation.valid}}
                            <p
                              class="workflows-canvas__ai-validation workflows-canvas__ai-validation--passed"
                            >
                              {{i18n
                                "discourse_workflows.ai.script_validation_passed"
                              }}
                            </p>
                          {{else}}
                            <div
                              class="workflows-canvas__ai-validation workflows-canvas__ai-validation--failed"
                            >
                              <p>{{i18n
                                  "discourse_workflows.ai.script_validation_failed"
                                }}</p>
                              <ul>
                                {{#each preview.validation.errors as |error|}}
                                  <li>{{error}}</li>
                                {{/each}}
                              </ul>
                            </div>
                          {{/if}}
                        {{/if}}
                      </section>
                    {{/each}}
                  </div>
                {{/if}}

                {{#if this.aiProposal.risks}}
                  <h5>{{i18n "discourse_workflows.ai.risks"}}</h5>
                  <ul>
                    {{#each this.aiProposal.risks as |risk|}}
                      <li>{{risk}}</li>
                    {{/each}}
                  </ul>
                {{/if}}
              </div>

              <div class="workflows-canvas__ai-review-footer">
                <DButton
                  @action={{this.applyAiProposal}}
                  @translatedLabel={{i18n "discourse_workflows.ai.apply"}}
                  class="btn-primary"
                />
              </div>
            </div>
          {{else}}
            <div class="workflows-canvas__ai-prompt-wrap">
              <label for="workflow-ai-prompt">
                {{i18n "discourse_workflows.ai.prompt_label"}}
              </label>
              <DTextarea
                id="workflow-ai-prompt"
                @value={{this.aiPrompt}}
                {{on "input" this.updateAiPrompt}}
                placeholder={{i18n "discourse_workflows.ai.prompt_placeholder"}}
                disabled={{this.aiGenerating}}
                class="workflows-canvas__ai-prompt"
              />
            </div>

            <div class="workflows-canvas__ai-panel-actions">
              {{#if this.aiCanReturnToPrompt}}
                <DButton
                  @action={{this.returnToAiPrompt}}
                  @translatedLabel={{i18n "discourse_workflows.ai.start_over"}}
                  @disabled={{this.aiGenerating}}
                  class="btn-default workflows-canvas__ai-start-over-btn"
                />
              {{/if}}

              <DButton
                @action={{this.submitAiPrompt}}
                @translatedLabel={{i18n "discourse_workflows.ai.generate"}}
                @isLoading={{this.aiGenerating}}
                @disabled={{this.aiSubmitDisabled}}
                class="btn-primary"
              />
            </div>
          {{/if}}

          {{#if this.aiResponseError}}
            <div
              class="workflows-canvas__ai-response workflows-canvas__ai-response--error"
            >
              <p>{{this.aiResponseError}}</p>
            </div>
          {{/if}}

          {{#if this.aiResponseMessage}}
            <div class="workflows-canvas__ai-response">
              <p>{{this.aiResponseMessage}}</p>
            </div>
          {{/if}}

          {{#if this.aiNeedsClarificationFallback}}
            <div class="workflows-canvas__ai-response">
              {{i18n "discourse_workflows.ai.needs_clarification"}}
            </div>
          {{/if}}
        </aside>
      </div>
    {{/if}}
  </template>
}
