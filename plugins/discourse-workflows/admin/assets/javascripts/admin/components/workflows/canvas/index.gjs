import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DTextarea from "discourse/ui-kit/d-textarea";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import CanvasContextMenu from "./canvas-context-menu";
import { exportWorkflowToFile, parseWorkflowImport } from "./canvas-file-io";
import { setupCanvasKeyboard } from "./canvas-keyboard";
import { runManualTrigger } from "./canvas-manual-trigger";
import {
  buildStickyNoteTranslateHandler,
  computeStickyNoteRects,
} from "./canvas-sticky-notes";
import ConnectionEntry from "./connection-entry";
import Controls from "./controls";
import LoopBackConnection from "./loop-back-connection";
import { createReteEditor } from "./rete-editor";
import StickyNoteComponent from "./sticky-note";
import WorkflowNode from "./workflow-node";

export default class WorkflowCanvas extends Component {
  @service keyboardShortcuts;
  @service dialog;
  @service menu;
  @service router;
  @service workflowsNodeTypes;
  @service toasts;
  @service siteSettings;
  @service messageBus;

  @tracked isLoading = true;
  @tracked rete = null;
  @tracked areaTransform = { x: 0, y: 0, k: 1 };
  @tracked workflowPublishedOverride = null;
  @tracked hasUnpublishedChangesOverride = null;
  @tracked selectionVersion = 0;
  @tracked aiPanelOpen = false;
  @tracked aiPrompt = "";
  @tracked aiGenerating = false;
  @tracked aiProgressEvents = [];
  @tracked aiResponse = null;
  @tracked aiSessionId = null;
  @tracked aiGenerationId = null;
  @tracked aiHighlightedNodeIds = new Set();
  @tracked aiClarificationAnswers = {};
  @tracked aiClarificationQuestionIndex = 0;
  @tracked aiError = null;
  copiedEntities = { nodes: [], stickyNotes: [] };
  pasteOffset = 0;
  isFirstSync = true;
  lastAutoArrangeRequest = 0;
  didHydrateInitialAutoLayout = false;
  #hasSetupStarted = false;
  #pendingSync = false;
  #syncTask = null;
  #ZOOM_STEP = 0.1;
  #ZOOM_MIN = 0.25;
  #ZOOM_MAX = 4;

  willDestroy() {
    super.willDestroy();
    this.rete?.destroy();
    this.keyboard?.teardown();
    this.unsubscribeFromAiAuthoring();
    clearTimeout(this.aiHighlightTimer);
  }

  get workflowPublished() {
    return (
      this.workflowPublishedOverride ?? Boolean(this.args.workflowPublished)
    );
  }

  get hasUnpublishedChanges() {
    return (
      this.hasUnpublishedChangesOverride ??
      Boolean(this.args.hasUnpublishedChanges)
    );
  }

  get publishDisabled() {
    return this.workflowPublished && !this.hasUnpublishedChanges;
  }

  get hasNodes() {
    return (this.args.nodes || []).length > 0;
  }

  get showPublishButton() {
    return this.hasNodes && !this.publishDisabled;
  }

  get showToolbarPublishButton() {
    return this.showPublishButton && !this.showUnpublishedChangesMessage;
  }

  get showUnpublishedChangesMessage() {
    return this.showPublishButton;
  }

  get showDiscardChangesButton() {
    return this.workflowPublished && this.hasUnpublishedChanges;
  }

  get aiAuthoringAvailable() {
    return (
      this.siteSettings.discourse_workflows_ai_authoring_enabled &&
      this.args.workflowId
    );
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

  get aiStepDescription() {
    return this.aiShowingProposalReview
      ? i18n("discourse_workflows.ai.review_description")
      : i18n("discourse_workflows.ai.description");
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

  @action
  isAiHighlightedNode(clientId) {
    this.aiHighlightedNodeIds;
    return this.aiHighlightedNodeIds.has(clientId?.toString());
  }

  #aiChangedNodeRefs() {
    const refs = { ids: new Set(), names: new Set() };

    for (const operation of this.aiProposal?.operations || []) {
      if (operation.op === "add_node" && operation.node?.name) {
        refs.names.add(operation.node.name);
      }

      for (const key of [
        "node_id",
        "client_id",
        "from",
        "from_node_id",
        "to",
        "to_node_id",
      ]) {
        if (operation[key]) {
          refs.ids.add(operation[key].toString());
        }
      }
    }

    return refs;
  }

  #highlightAiChangedNodes(workflow, refs) {
    const nodeIds = new Set();
    for (const node of workflow?.nodes || []) {
      if (refs.ids.has(node.id?.toString()) || refs.names.has(node.name)) {
        nodeIds.add(node.id?.toString());
      }
    }

    this.aiHighlightedNodeIds = nodeIds;
    clearTimeout(this.aiHighlightTimer);
    this.aiHighlightTimer = setTimeout(() => {
      this.aiHighlightedNodeIds = new Set();
    }, 6000);
  }

  #aiAjaxErrorMessage(error) {
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
      this.aiError = this.#aiAjaxErrorMessage(error);
    }
  }

  @action
  openAiPanel() {
    this.aiPanelOpen = true;
  }

  @action
  closeAiPanel() {
    this.aiPanelOpen = false;
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

    const changedNodeRefs = this.#aiChangedNodeRefs();

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
      this.args.onAiWorkflowApplied?.(response.workflow);
      this.#highlightAiChangedNodes(response.workflow, changedNodeRefs);
      this.aiResponse = null;
      this.aiProgressEvents = [];
      this.aiClarificationAnswers = {};
      this.aiClarificationQuestionIndex = 0;
      this.aiPrompt = "";
      this.aiSessionId = null;
      this.aiGenerationId = null;
      this.aiError = null;
      this.aiPanelOpen = false;
      this.toasts.success({
        data: { message: i18n("discourse_workflows.ai.applied") },
      });
    } catch (error) {
      this.aiError = this.#aiAjaxErrorMessage(error);
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

  @action
  isStickyNoteSelected(clientId) {
    this.selectionVersion;
    return this.rete.isStickyNoteSelected(clientId);
  }

  @action
  async publishWorkflow() {
    if (!this.hasNodes) {
      return;
    }

    this.workflowPublishedOverride = true;
    this.hasUnpublishedChangesOverride = false;
    try {
      await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflowId}.json`,
        {
          type: "PUT",
          data: {
            workflow: {
              name: this.args.workflowName,
              published: true,
            },
          },
        }
      );
      if (this.args.workflow) {
        this.args.workflow.activeVersionId = this.args.workflow.versionId;
        this.args.workflow.hasUnpublishedChanges = false;
      }
      this.workflowPublishedOverride = null;
      this.hasUnpublishedChangesOverride = null;
    } catch {
      this.workflowPublishedOverride = this.args.workflowPublished;
      this.hasUnpublishedChangesOverride = this.args.hasUnpublishedChanges;
    }
  }

  @action
  async discardWorkflow() {
    const confirmed = await this.dialog.confirm({
      message: i18n("discourse_workflows.discard_changes_confirmation"),
      confirmButtonLabel: "discourse_workflows.discard_changes",
      cancelButtonLabel: "discourse_workflows.keep_editing",
    });

    if (!confirmed) {
      return;
    }

    this.hasUnpublishedChangesOverride = false;

    try {
      const response = await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflowId}/discard-draft.json`,
        {
          type: "POST",
        }
      );

      this.args.onDiscardWorkflow?.(response.workflow);
      this.hasUnpublishedChangesOverride = null;
    } catch (e) {
      this.hasUnpublishedChangesOverride = this.args.hasUnpublishedChanges;
      popupAjaxError(e);
    }
  }

  @action
  async unpublishWorkflow(closeMenu) {
    if (typeof closeMenu === "function") {
      closeMenu();
    }
    this.workflowPublishedOverride = false;
    try {
      await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflowId}.json`,
        {
          type: "PUT",
          data: {
            workflow: {
              name: this.args.workflowName,
              published: false,
            },
          },
        }
      );
      if (this.args.workflow) {
        this.args.workflow.activeVersionId = null;
        this.args.workflow.hasUnpublishedChanges = true;
      }
      this.workflowPublishedOverride = null;
    } catch {
      this.workflowPublishedOverride = this.args.workflowPublished;
    }
  }

  @action
  registerCanvas(element) {
    this.canvasElement = element;
    this.#maybeSetupCanvas();
  }

  @action
  registerContainer(element) {
    this.containerElement = element;
    this.#maybeSetupCanvas();
  }

  #keyboardActions() {
    return {
      onUndo: () => this.args.onUndo?.(),
      onRedo: () => this.args.onRedo?.(),
      onCopy: () => this.#copy(),
      onPaste: () => this.#paste(),
      onDelete: () => this.deleteSelected(),
      onEscape: () => {
        this.contextMenuApi?.close();
        this.rete.selector.unselectAll();
        this.selectionVersion++;
      },
      onZoomIn: () => this.zoomIn(),
      onZoomOut: () => this.zoomOut(),
      onFitToView: () => this.fitToView(),
      onAutoLayout: () => this.autoLayout(),
    };
  }

  async #handleManualTrigger(clientId) {
    try {
      await runManualTrigger({
        node: this.#nodes().find((n) => n.clientId === clientId),
        clientId,
        workflowId: this.args.workflowId,
        toasts: this.toasts,
        router: this.router,
        session: this.args.session,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  #reteCallbacks() {
    return {
      onNodeDragged: (...a) => this.args.onUpdateNodePosition?.(...a),
      onNodePicked: () => this.selectionVersion++,
      onCanvasPointerDown: () => {
        this.selectionVersion++;
        this.contextMenuApi?.close();
        this.menu.close("workflows-canvas-menu");
        this.args.onCloseNodePanel?.();
      },
      onNodeDragEnd: () => this.args.onNodeDragEnd?.(),
      onConnectionCreated: (...a) => this.args.onCreateConnection?.(...a),
      onNodeDelete: (clientId) => this.args.onRemoveNodes?.([clientId]),
      onManualTrigger: (clientId) => this.#handleManualTrigger(clientId),
      onNodeDoubleClick: (clientId) => this.args.onEditNode?.(clientId),
      onTransformChanged: (t) => (this.areaTransform = t),
    };
  }

  #nodes() {
    return this.args.nodes || [];
  }

  #connections() {
    return this.args.connections || [];
  }

  #stickyNoteRects() {
    return computeStickyNoteRects(this.args.stickyNotes);
  }

  #shouldHydrateInitialAutoLayout(nodes) {
    return (
      !this.didHydrateInitialAutoLayout && nodes.some((node) => !node.position)
    );
  }

  #consumeAutoArrangeRequest(autoArrangeRequest) {
    if (autoArrangeRequest <= this.lastAutoArrangeRequest) {
      return false;
    }

    this.lastAutoArrangeRequest = autoArrangeRequest;
    return true;
  }

  async #applyAutoArrange(callback) {
    const positions = await this.rete.autoArrange();
    callback?.(positions);
  }

  async #syncViewport(prevNodeCount, stickyNoteRects) {
    if (this.isFirstSync || this.rete.nodeCount !== prevNodeCount) {
      this.isFirstSync = false;
      await this.rete.fitToView(stickyNoteRects);
    }
  }

  async #performSync() {
    const snapshot = {
      nodes: this.#nodes(),
      connections: this.#connections(),
      stickyNoteRects: this.#stickyNoteRects(),
      autoArrangeRequest: this.args.autoArrangeRequest || 0,
    };
    const prevNodeCount = this.rete.nodeCount;

    await this.rete.syncState(snapshot.nodes, snapshot.connections);

    if (this.#shouldHydrateInitialAutoLayout(snapshot.nodes)) {
      this.didHydrateInitialAutoLayout = true;
      await this.#applyAutoArrange(this.args.onHydrateAutoLayout);
    }

    if (this.#consumeAutoArrangeRequest(snapshot.autoArrangeRequest)) {
      await this.#applyAutoArrange(this.args.onSyncAutoLayout);
    }

    await this.#syncViewport(prevNodeCount, snapshot.stickyNoteRects);
  }

  async #flushSyncQueue() {
    try {
      while (this.#pendingSync) {
        this.#pendingSync = false;
        await this.#performSync();
      }
    } catch {
      this.#pendingSync = false;
      this.toasts.error({
        data: { message: i18n("discourse_workflows.canvas.sync_error") },
      });
    } finally {
      this.#syncTask = null;
    }
  }

  async #queueSync() {
    if (!this.rete) {
      return;
    }

    this.#pendingSync = true;

    if (!this.#syncTask) {
      this.#syncTask = this.#flushSyncQueue();
    }

    await this.#syncTask;
  }

  async #maybeSetupCanvas() {
    if (
      this.#hasSetupStarted ||
      !this.canvasElement ||
      !this.containerElement
    ) {
      return;
    }

    this.#hasSetupStarted = true;
    const element = this.canvasElement;
    const nodeTypes = await this.workflowsNodeTypes.load();

    this.rete = await createReteEditor(this.containerElement, {
      nodeTypes,
      callbacks: this.#reteCallbacks(),
    });

    this.keyboard = setupCanvasKeyboard(
      this.keyboardShortcuts,
      this.#keyboardActions(),
      element
    );

    this.args.onAreaReady?.(this.rete.area);

    await this.#queueSync();
    this.isLoading = false;
    element.focus();
  }

  @action
  async syncToRete() {
    await this.#queueSync();
  }

  get nodeEntries() {
    return this.rete.renderer.nodeEntryList;
  }

  get connectionEntries() {
    return this.rete.renderer.connectionEntryList;
  }

  get handleEntries() {
    return [
      ...this.rete.renderer.outputHandleEntryList,
      ...this.rete.renderer.inputHandleEntryList,
    ].map((entry) => ({
      ...entry,
      svgStyle: trustHTML(
        `overflow:visible;position:absolute;pointer-events:none;z-index:2;left:${entry.svgLeft}px;top:${entry.svgTop}px;width:50px;height:20px`
      ),
    }));
  }

  get areaContentElement() {
    return this.rete.areaContentElement;
  }

  @action
  handleConnectionToolbarAdd(connectionInfo) {
    this.args.onOpenNodePanel?.({
      connectionSource: connectionInfo.sourceClientId,
      connectionSourceOutput: connectionInfo.sourceOutput,
      connectionTarget: connectionInfo.targetClientId,
      connectionTargetInput: connectionInfo.targetInput,
    });
  }

  @action
  handleConnectionToolbarDelete(connectionInfo) {
    this.args.onConnectionDelete?.(
      connectionInfo.sourceClientId,
      connectionInfo.sourceOutput,
      connectionInfo.targetClientId,
      connectionInfo.targetInput
    );
  }

  @action
  handleLoopBackAdd(loopNodeClientId) {
    this.args.onOpenNodePanel?.({ loopNodeClientId });
  }

  @action
  handleHandleAdd(nodeClientId, outputKey, inputKey, e) {
    e.stopPropagation();
    this.args.onOpenNodePanel?.(
      outputKey !== null
        ? { sourceClientId: nodeClientId, sourceOutput: outputKey }
        : { targetClientId: nodeClientId, targetInput: inputKey || "main" }
    );
  }

  get showEmptyState() {
    return !this.isLoading && (this.args.nodes || []).length === 0;
  }

  @action
  registerContextMenu(api) {
    this.contextMenuApi = api;
  }

  @action
  handleContextMenu(event) {
    this.contextMenuApi?.open(event);
  }

  #invokeAtViewportCenter(callback) {
    this.contextMenuApi?.close();
    callback?.(this.rete.viewportCenter());
  }

  @action
  openNodePanelAtCenter() {
    this.#invokeAtViewportCenter(this.args.onOpenNodePanel);
  }

  @action
  browseTemplates() {
    this.args.onBrowseTemplates?.();
  }

  @action
  async selectStickyNote(clientId) {
    await this.rete.selectStickyNote(clientId, {
      onStickyNoteTranslate: buildStickyNoteTranslateHandler(
        this.args.stickyNotes,
        this.args.onStickyNoteMove
      ),
      onStickyNoteUnselect: () => {
        this.selectionVersion++;
      },
    });
    this.selectionVersion++;
  }

  #copy() {
    const { nodeIds, stickyNoteIds } = this.rete.getSelectedIds();
    const cloneMatching = (items, ids) =>
      (items || []).filter((n) => ids.has(n.clientId)).map(structuredClone);
    const nodes = cloneMatching(this.args.nodes, nodeIds);
    const stickyNotes = cloneMatching(this.args.stickyNotes, stickyNoteIds);
    if (nodes.length > 0 || stickyNotes.length > 0) {
      this.copiedEntities = { nodes, stickyNotes };
      this.pasteOffset = 0;
    }
  }

  #paste() {
    const { nodes, stickyNotes } = this.copiedEntities;
    if (nodes.length === 0 && stickyNotes.length === 0) {
      return;
    }
    this.pasteOffset += 20;
    const offset = this.pasteOffset;
    const shift = (items) =>
      items.map((item) => ({
        ...item,
        position: item.position
          ? { x: item.position.x + offset, y: item.position.y + offset }
          : null,
      }));
    this.args.onPasteEntities?.({
      nodes: shift(nodes),
      stickyNotes: shift(stickyNotes),
    });
  }

  @action
  addStickyNoteAtCenter(closeFn) {
    closeFn?.();
    this.#invokeAtViewportCenter(this.args.onAddStickyNote);
  }

  @action
  deleteStickyNote(clientId) {
    this.args.onRemoveSelected?.({
      nodeIds: [],
      stickyNoteIds: [clientId],
    });
    this.selectionVersion++;
  }

  @action
  async translateSelected(draggedClientId, dx, dy) {
    await this.rete.translateSelectedEntities(
      draggedClientId,
      "sticky-note",
      dx,
      dy
    );
  }

  @action
  deleteSelected() {
    const { nodeIds, stickyNoteIds } = this.rete.getSelectedIds();
    if (nodeIds.size > 0 || stickyNoteIds.size > 0) {
      this.args.onRemoveSelected?.({
        nodeIds: [...nodeIds],
        stickyNoteIds: [...stickyNoteIds],
      });
      this.rete.selector.unselectAll();
      this.selectionVersion++;
    }
  }

  async #applyZoom(delta) {
    const currentK = this.rete.transform.k;
    const newK = Math.max(
      this.#ZOOM_MIN,
      Math.min(this.#ZOOM_MAX, currentK + delta)
    );
    await this.rete.zoomAtViewportCenter(newK);
  }

  @action
  async zoomIn() {
    await this.#applyZoom(this.#ZOOM_STEP);
  }

  @action
  async zoomOut() {
    await this.#applyZoom(-this.#ZOOM_STEP);
  }

  @action
  async fitToView() {
    await this.rete.fitToView(this.#stickyNoteRects());
  }

  @action
  async autoLayout() {
    const positions = await this.rete.autoArrange();
    this.args.onAutoLayout?.(positions);
    await this.rete.fitToView(this.#stickyNoteRects());
  }

  @action
  exportWorkflow(closeFn) {
    closeFn();
    exportWorkflowToFile(
      this.args.nodes,
      this.args.connections,
      this.args.stickyNotes,
      this.args.workflow
    );
  }

  @action
  openImportDialog(closeFn) {
    closeFn();
    this.fileInput?.click();
  }

  @action
  registerFileInput(element) {
    this.fileInput = element;
  }

  #showImportError(key = "import_error") {
    this.toasts.error({
      data: { message: i18n(`discourse_workflows.canvas.${key}`) },
    });
  }

  @action
  async handleFileSelected(event) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) {
      return;
    }
    try {
      const result = parseWorkflowImport(await file.text());
      if (result.error) {
        this.#showImportError(
          result.error === "version" ? "import_version_error" : "import_error"
        );
        return;
      }
      this.args.onImportNodes?.(
        result.nodes,
        result.connections,
        result.stickyNotes,
        result.staticData
      );
    } catch {
      this.#showImportError();
    }
  }

  <template>
    <div
      class="workflows-canvas"
      tabindex="0"
      {{on "contextmenu" this.handleContextMenu}}
      {{didInsert this.registerCanvas}}
      {{didUpdate this.syncToRete @nodes @connections @autoArrangeRequest}}
    >
      {{#if this.isLoading}}
        <div class="workflows-canvas__spinner-overlay">
          <div class="spinner"></div>
        </div>
      {{/if}}

      <div
        class="workflows-canvas__rete-container"
        {{didInsert this.registerContainer}}
      ></div>

      {{#if this.rete}}
        {{#if this.showEmptyState}}
          <div class="workflows-canvas__empty-state">
            <div class="workflows-canvas__empty-state-options">
              <button
                type="button"
                class="workflows-canvas__empty-state-trigger"
                {{on "click" this.openNodePanelAtCenter}}
              >
                <span class="workflows-canvas__empty-state-tile">
                  {{dIcon "plus"}}
                </span>
                <span class="workflows-canvas__empty-state-label">
                  {{i18n "discourse_workflows.add_node.first_step"}}
                </span>
              </button>

              <button
                type="button"
                class="workflows-canvas__empty-state-trigger"
                {{on "click" this.browseTemplates}}
              >
                <span class="workflows-canvas__empty-state-tile">
                  {{dIcon "layer-group"}}
                </span>
                <span class="workflows-canvas__empty-state-label">
                  {{i18n "discourse_workflows.add_node.browse_templates"}}
                </span>
              </button>
            </div>
          </div>
        {{/if}}

        {{#each this.nodeEntries as |entry|}}
          {{#in-element entry.element insertBefore=null}}
            <WorkflowNode
              @node={{entry.node}}
              @onDelete={{this.rete.renderer.onNodeDelete}}
              @onManualTrigger={{this.rete.renderer.onManualTrigger}}
              @onSocketRendered={{this.rete.renderer.onSocketRendered}}
              @onEditNode={{@onEditNode}}
              @workflowPublished={{this.workflowPublished}}
              @session={{@session}}
              @aiHighlighted={{this.isAiHighlightedNode entry.node.id}}
            />
          {{/in-element}}
        {{/each}}

        {{#each this.connectionEntries as |entry|}}
          {{#in-element entry.element insertBefore=null}}
            {{#if entry.isLoopBack}}
              <LoopBackConnection
                @entry={{entry}}
                @onAdd={{this.handleLoopBackAdd}}
              />
            {{else}}
              <ConnectionEntry
                @entry={{entry}}
                @onAdd={{this.handleConnectionToolbarAdd}}
                @onDelete={{this.handleConnectionToolbarDelete}}
              />
            {{/if}}
          {{/in-element}}
        {{/each}}

        {{#each this.handleEntries as |entry|}}
          {{#in-element entry.areaElement insertBefore=null}}

            <svg class="workflow-handle" style={{entry.svgStyle}}>
              <path
                fill="none"
                stroke="var(--primary-low-mid)"
                stroke-width="1.5"
                d={{entry.pathD}}
              />
              <foreignObject
                class="workflow-handle__button-fo"
                width="14"
                height="14"
                x={{entry.buttonX}}
                y={{entry.buttonY}}
              >
                <button
                  type="button"
                  class="workflow-handle__add-btn"
                  {{on
                    "click"
                    (fn
                      this.handleHandleAdd
                      entry.nodeClientId
                      entry.outputKey
                      entry.inputKey
                    )
                  }}
                >
                  {{dIcon "plus"}}
                </button>
              </foreignObject>
            </svg>
          {{/in-element}}
        {{/each}}

        {{#if this.areaContentElement}}
          {{#each @stickyNotes key="clientId" as |note|}}
            {{#in-element this.areaContentElement insertBefore=null}}
              <StickyNoteComponent
                @note={{note}}
                @isSelected={{this.isStickyNoteSelected note.clientId}}
                @zoom={{this.areaTransform.k}}
                @onSelect={{fn this.selectStickyNote note.clientId}}
                @onBeforeMutation={{@onStickyNoteBeforeMutation}}
                @onMove={{fn @onStickyNoteMove note.clientId}}
                @onResize={{fn @onStickyNoteResize note.clientId}}
                @onUpdateText={{fn @onStickyNoteUpdateText note.clientId}}
                @onChangeColor={{fn @onStickyNoteChangeColor note.clientId}}
                @onDelete={{fn this.deleteStickyNote note.clientId}}
                @onTranslateSelected={{fn this.translateSelected note.clientId}}
                @onAfterMutation={{@onNodeDragEnd}}
              />
            {{/in-element}}
          {{/each}}
        {{/if}}

        <Controls
          @onUndo={{@onUndo}}
          @onRedo={{@onRedo}}
          @canUndo={{@canUndo}}
          @canRedo={{@canRedo}}
          @onZoomIn={{this.zoomIn}}
          @onZoomOut={{this.zoomOut}}
          @onFitToView={{this.fitToView}}
          @onAutoLayout={{this.autoLayout}}
        />

        <input
          type="file"
          accept=".json"
          class="hidden"
          {{didInsert this.registerFileInput}}
          {{on "change" this.handleFileSelected}}
        />

        {{#if @onOpenNodePanel}}
          <div class="workflows-canvas__top-bar">
            {{#if this.showUnpublishedChangesMessage}}
              <div class="workflows-canvas__publish-status">
                <span
                  class="workflows-canvas__publish-status-body"
                  role="status"
                >
                  <span class="workflows-canvas__publish-status-icon">
                    {{dIcon "triangle-exclamation"}}
                  </span>
                  <span class="workflows-canvas__publish-status-text">
                    <span class="workflows-canvas__publish-status-title">
                      {{i18n "discourse_workflows.unpublished_changes_message"}}
                    </span>
                    <span class="workflows-canvas__publish-status-detail">
                      {{i18n
                        "discourse_workflows.unpublished_changes_message_detail"
                      }}
                    </span>
                  </span>
                </span>

                <span class="workflows-canvas__publish-status-actions">
                  <DButton
                    @action={{this.publishWorkflow}}
                    @translatedLabel={{i18n "discourse_workflows.publish"}}
                    class="btn-primary btn-small workflows-canvas__publish-status-btn"
                  />

                  {{#if this.showDiscardChangesButton}}
                    <DButton
                      @action={{this.discardWorkflow}}
                      @translatedLabel={{i18n
                        "discourse_workflows.discard_changes"
                      }}
                      class="btn-default btn-small workflows-canvas__publish-status-btn"
                    />
                  {{/if}}
                </span>
              </div>
            {{/if}}

            <div class="workflows-canvas__toolbar-top-right">
              {{#if this.showToolbarPublishButton}}
                <DButton
                  @action={{this.publishWorkflow}}
                  @translatedLabel={{i18n "discourse_workflows.publish"}}
                  class="btn-primary workflows-canvas__publish-btn"
                />
              {{/if}}

              {{#if this.aiAuthoringAvailable}}
                <DButton
                  @action={{this.openAiPanel}}
                  @icon="bolt"
                  @translatedLabel={{i18n "discourse_workflows.ai.button"}}
                  class="btn-default workflows-canvas__ai-btn"
                />
              {{/if}}

              <DButton
                @action={{this.openNodePanelAtCenter}}
                @icon="plus"
                class="btn-default workflows-canvas__add-node-btn"
              />

              <DMenu
                @identifier="workflows-canvas-menu"
                @icon="ellipsis-vertical"
                class="btn-default workflows-canvas__menu-btn"
              >
                <:content as |args|>
                  <DDropdownMenu as |dropdown|>
                    {{#if this.workflowPublished}}
                      <dropdown.item>
                        <DButton
                          @action={{fn this.unpublishWorkflow args.close}}
                          @translatedLabel={{i18n
                            "discourse_workflows.unpublish"
                          }}
                          class="btn-transparent"
                        />
                      </dropdown.item>
                    {{/if}}
                    <dropdown.item>
                      <DButton
                        @action={{fn this.addStickyNoteAtCenter args.close}}
                        @icon="note-sticky"
                        @translatedLabel={{i18n
                          "discourse_workflows.sticky_note.add"
                        }}
                        class="btn-transparent"
                      />
                    </dropdown.item>
                    <dropdown.item>
                      <DButton
                        @action={{fn this.exportWorkflow args.close}}
                        @icon="download"
                        @translatedLabel={{i18n
                          "discourse_workflows.canvas.export_nodes"
                        }}
                        @disabled={{this.showEmptyState}}
                        class="btn-transparent"
                      />
                    </dropdown.item>
                    <dropdown.item>
                      <DButton
                        @action={{fn this.openImportDialog args.close}}
                        @icon="upload"
                        @translatedLabel={{i18n
                          "discourse_workflows.canvas.import_nodes"
                        }}
                        class="btn-transparent"
                      />
                    </dropdown.item>
                  </DDropdownMenu>
                </:content>
              </DMenu>
            </div>
          </div>
        {{/if}}

        {{#if this.aiPanelOpen}}
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
                  <span class="workflows-canvas__ai-title-icon">
                    {{dIcon "bolt"}}
                  </span>
                  <div>
                    <h3 id="workflow-ai-panel-title">
                      {{i18n "discourse_workflows.ai.title"}}
                    </h3>
                    <p>{{i18n "discourse_workflows.ai.subtitle"}}</p>
                  </div>
                </div>
                <DButton
                  @action={{this.closeAiPanel}}
                  @icon="xmark"
                  @title="discourse_workflows.ai.close"
                  class="btn-transparent workflows-canvas__ai-close"
                />
              </div>

              <div class="workflows-canvas__ai-status-row">
                <span
                  class={{dConcatClass
                    "workflows-canvas__ai-status"
                    this.aiStatusClass
                  }}
                >
                  {{this.aiStatusLabel}}
                </span>
                <span class="workflows-canvas__ai-panel-description">
                  {{this.aiStepDescription}}
                </span>
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
                          {{#each
                            (this.aiQuestionOptions question)
                            as |option|
                          }}
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
                              {{#if
                                (this.aiClarificationOptionDescription option)
                              }}
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
                              (fn
                                this.updateAiClarificationCustom question index
                              )
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
                      @translatedLabel={{i18n
                        "discourse_workflows.ai.start_over"
                      }}
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
                      @icon="bolt"
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
                        <h5>{{i18n
                            "discourse_workflows.ai.created_agents"
                          }}</h5>
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
                        <h5>{{i18n
                            "discourse_workflows.ai.script_preview"
                          }}</h5>
                        {{#each this.aiCodePreviews as |preview|}}
                          <section class="workflows-canvas__ai-code-preview">
                            <div
                              class="workflows-canvas__ai-code-preview-header"
                            >
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
                                    {{#each
                                      preview.validation.errors
                                      as |error|
                                    }}
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
                    placeholder={{i18n
                      "discourse_workflows.ai.prompt_placeholder"
                    }}
                    disabled={{this.aiGenerating}}
                    class="workflows-canvas__ai-prompt"
                  />
                </div>

                <div class="workflows-canvas__ai-panel-actions">
                  {{#if this.aiCanReturnToPrompt}}
                    <DButton
                      @action={{this.returnToAiPrompt}}
                      @translatedLabel={{i18n
                        "discourse_workflows.ai.start_over"
                      }}
                      @disabled={{this.aiGenerating}}
                      class="btn-default workflows-canvas__ai-start-over-btn"
                    />
                  {{/if}}

                  <DButton
                    @action={{this.submitAiPrompt}}
                    @icon="bolt"
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

        <CanvasContextMenu
          @canvasElement={{this.canvasElement}}
          @containerElement={{this.containerElement}}
          @rete={{this.rete}}
          @onEditNode={{@onEditNode}}
          @onDeleteSelected={{this.deleteSelected}}
          @onOpenNodePanel={{@onOpenNodePanel}}
          @onAddStickyNote={{@onAddStickyNote}}
          @onRegister={{this.registerContextMenu}}
        />
      {{/if}}
    </div>
  </template>
}
