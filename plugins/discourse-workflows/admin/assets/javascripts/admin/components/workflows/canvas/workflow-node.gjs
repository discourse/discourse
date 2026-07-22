import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import formatNodeIssue from "../../../lib/workflows/format-node-issue";
import getNodeIssues from "../../../lib/workflows/node-issues";
import {
  nodeTypeIcon,
  nodeTypeInputLabel,
  nodeTypeIsManuallyTriggerable,
  nodeTypePortLabel,
  nodeTypeRunScopeLabelKey,
  nodeTypeStyle,
  resolveNodeTypeVersion,
  typeVersionForNode,
} from "../../../lib/workflows/node-types";
import { nodeDescription, nodeLabel } from "../../../lib/workflows/node-utils";
import CanvasHoverToolbar from "./hover-toolbar";

function resolveType(workflowsNodeTypes, node) {
  const nodeType = workflowsNodeTypes.findNodeType(node.type);
  if (!nodeType) {
    return null;
  }

  return resolveNodeTypeVersion(nodeType, typeVersionForNode(node));
}

const highlightOnInsert = modifier((element) => {
  if (window.matchMedia?.("(prefers-reduced-motion: reduce)").matches) {
    return;
  }

  const removeHighlight = () => element.classList.remove("is-highlighted");

  element.classList.add("is-highlighted");
  element.addEventListener("animationend", removeHighlight, { once: true });

  return () => {
    element.removeEventListener("animationend", removeHighlight);
    removeHighlight();
  };
});

export function shouldShowManualTrigger(node) {
  return Boolean(node?.type?.startsWith("trigger:"));
}

export function shouldEnableManualTrigger(node, nodeType, session) {
  if (!node?.type?.startsWith("trigger:")) {
    return false;
  }

  return Boolean(
    nodeTypeIsManuallyTriggerable(nodeType, node.typeVersion) ||
    session?.isNodePinned(node.name)
  );
}

export default class WorkflowNode extends Component {
  @service router;
  @service workflowsNodeTypes;

  stopPropagation = (e) => e.stopPropagation();

  handleDelete = (e) => {
    e.stopPropagation();
    e.preventDefault();
    this.args.onDelete?.(this.data.clientId);
  };

  handleManualTrigger = (e) => {
    e.stopPropagation();
    this.args.onManualTrigger?.(this.data.clientId);
  };

  handleOpenIssues = (e) => {
    e.stopPropagation();
    e.preventDefault();
    this.args.onEditNode?.(this.data.clientId);
  };

  portLabel = (key) => {
    return nodeTypePortLabel(this.resolvedNodeType, key);
  };

  formatIssue = (issue) => {
    return formatNodeIssue(issue, this.resolvedNodeType);
  };

  get data() {
    return this.args.node.workflowData;
  }

  get resolvedNodeType() {
    return resolveType(this.workflowsNodeTypes, this.data);
  }

  get isTrigger() {
    return this.data.type?.startsWith("trigger:");
  }

  get isBranching() {
    return Object.keys(this.args.node.outputs).length > 1;
  }

  get label() {
    return nodeLabel(this.data, this.resolvedNodeType);
  }

  get description() {
    return nodeDescription(this.data);
  }

  get runScopeLabel() {
    const labelKey = nodeTypeRunScopeLabelKey(this.resolvedNodeType, this.data);
    return labelKey ? i18n(labelKey) : null;
  }

  get outputKeys() {
    return Object.keys(this.args.node.outputs);
  }

  get hasMultipleInputs() {
    return Object.keys(this.args.node.inputs).length > 1;
  }

  get inputEntries() {
    return Object.keys(this.args.node.inputs).map((key) => ({
      key,
      input: this.args.node.inputs[key],
      label: nodeTypeInputLabel(this.resolvedNodeType, key, this.data),
    }));
  }

  get isUnavailable() {
    const nodeType = this.resolvedNodeType;
    return !nodeType || nodeType.available === false;
  }

  get unavailableReasonKey() {
    return this.resolvedNodeType?.unavailable_reason_key;
  }

  get unavailableReason() {
    return i18n(
      this.unavailableReasonKey ||
        "discourse_workflows.node_unavailable.default"
    );
  }

  get unavailableLabel() {
    return i18n("discourse_workflows.node_unavailable.short");
  }

  get isManuallyTriggerable() {
    return shouldEnableManualTrigger(
      this.data,
      this.resolvedNodeType,
      this.args.session
    );
  }

  get showManualTrigger() {
    return shouldShowManualTrigger(this.data);
  }

  get manualTriggerLabel() {
    return this.isManuallyTriggerable
      ? i18n("discourse_workflows.manual_trigger.run")
      : i18n("discourse_workflows.manual_trigger.needs_pin_data");
  }

  get dataTableId() {
    if (this.data.type !== "action:data_table") {
      return null;
    }
    return this.data.configuration?.data_table_id;
  }

  @action
  handleEditDataTable(e) {
    e.stopPropagation();
    e.preventDefault();
    this.router.transitionTo(
      "adminPlugins.show.discourse-workflows-data-tables.show",
      this.dataTableId
    );
  }

  get iconBlockStyle() {
    return nodeTypeStyle(this.resolvedNodeType);
  }

  get dimensionsStyle() {
    return trustHTML(
      `width: ${this.args.node.width}px; height: ${this.args.node.height}px;`
    );
  }

  get issues() {
    const nodeType = this.resolvedNodeType;
    if (!nodeType || typeof nodeType === "string") {
      return [];
    }
    return getNodeIssues(this.data.configuration, nodeType.properties);
  }

  <template>
    {{! eslint-disable ember/template-no-pointer-down-event-binding }}
    <div
      class={{dConcatClass
        "workflow-rete-node"
        (if this.isTrigger "is-trigger")
        (if this.isBranching "is-branching")
        (if @node.selected "is-selected")
        (if this.isUnavailable "is-unavailable")
      }}
      style={{this.dimensionsStyle}}
      data-client-id={{this.data.clientId}}
      data-unavailable={{if this.isUnavailable "true" "false"}}
      {{highlightOnInsert}}
    >
      {{#if @node.selected}}
        {{#if this.runScopeLabel}}
          <div class="workflow-rete-node__run-scope-tooltip">
            {{this.runScopeLabel}}
          </div>
        {{/if}}
      {{/if}}

      <div class="workflow-rete-node__icon-row">
        <div
          class={{dConcatClass
            "workflow-rete-node__inputs"
            (if this.hasMultipleInputs "has-multiple-inputs")
          }}
        >
          {{#each this.inputEntries as |entry|}}
            <div class="workflow-rete-node__input-row">
              {{#if this.hasMultipleInputs}}
                <span class="workflow-rete-node__input-label">
                  {{entry.label}}
                </span>
              {{/if}}
              <div
                class="workflow-rete-node__socket --input"
                data-socket-key={{entry.key}}
                {{didInsert
                  (fn
                    @onSocketRendered
                    @node.id
                    "input"
                    entry.key
                    entry.input.socket
                  )
                }}
              />
            </div>
          {{/each}}
        </div>

        <div
          class="workflow-rete-node__icon-block"
          style={{this.iconBlockStyle}}
        >
          <CanvasHoverToolbar @hoverSelector=".workflow-rete-node">
            {{#if this.showManualTrigger}}
              <DTooltip
                @identifier="workflow-node-manual-trigger"
                @content={{this.manualTriggerLabel}}
              >
                <:trigger>
                  <button
                    type="button"
                    class={{dConcatClass
                      "workflow-canvas-toolbar__btn --success"
                      (if this.isManuallyTriggerable "" "is-disabled")
                    }}
                    disabled={{if this.isManuallyTriggerable false true}}
                    aria-label={{this.manualTriggerLabel}}
                    {{on "pointerdown" this.stopPropagation}}
                    {{on "click" this.handleManualTrigger}}
                  >
                    {{dIcon "play"}}
                  </button>
                </:trigger>
              </DTooltip>
            {{/if}}
            {{#if this.dataTableId}}
              <button
                type="button"
                class="workflow-canvas-toolbar__btn"
                {{on "pointerdown" this.stopPropagation}}
                {{on "click" this.handleEditDataTable}}
              >
                {{dIcon "eye"}}
              </button>
            {{/if}}
            <button
              type="button"
              class="workflow-canvas-toolbar__btn"
              {{on "pointerdown" this.stopPropagation}}
              {{on "click" this.handleDelete}}
            >
              {{dIcon "trash-can"}}
            </button>
          </CanvasHoverToolbar>

          {{#if this.isUnavailable}}
            <span
              class="workflow-rete-node__unavailable-icon"
              aria-label={{this.unavailableReason}}
            >
              {{dIcon "triangle-exclamation"}}
            </span>
          {{else if (nodeTypeIcon this.resolvedNodeType)}}
            <span class="workflow-rete-node__icon">
              {{dIcon (nodeTypeIcon this.resolvedNodeType)}}
            </span>
          {{/if}}

          {{#if this.issues.length}}
            <DTooltip
              @identifier="workflow-node-issues"
              class="workflow-rete-node__issues-badge"
              {{on "pointerdown" this.stopPropagation}}
              {{on "click" this.handleOpenIssues}}
            >
              <:trigger>
                {{dIcon "triangle-exclamation"}}
              </:trigger>
              <:content>
                <div class="workflow-rete-node__issues">
                  <div class="workflow-rete-node__issues-title">
                    {{i18n "discourse_workflows.node_issues.title"}}
                  </div>
                  <ul class="workflow-rete-node__issues-list">
                    {{#each this.issues as |issue|}}
                      <li>{{this.formatIssue issue}}</li>
                    {{/each}}
                  </ul>
                </div>
              </:content>
            </DTooltip>
          {{/if}}
        </div>

        <div class="workflow-rete-node__outputs">
          {{#each this.outputKeys as |key|}}
            <div class="workflow-rete-node__output-row">
              <div
                class={{dConcatClass
                  "workflow-rete-node__socket --output"
                  (if (eq key "loop") "--loop")
                }}
                data-socket-key={{key}}
                {{didInsert
                  (fn @onSocketRendered @node.id "output" key @node.outputs)
                }}
              />
              {{#if this.isBranching}}
                <span class="workflow-rete-node__port-pill">
                  {{this.portLabel key}}
                </span>
              {{/if}}
            </div>
          {{/each}}
        </div>
      </div>

      <span class="workflow-rete-node__label">{{this.label}}</span>

      {{#if this.isUnavailable}}
        <DTooltip
          @identifier="workflow-node-unavailable"
          @content={{this.unavailableReason}}
        >
          <:trigger>
            <span class="workflow-rete-node__unavailable-pill">
              {{this.unavailableLabel}}
            </span>
          </:trigger>
        </DTooltip>
      {{/if}}

      {{#if this.description}}
        <span
          class="workflow-rete-node__description"
        >{{this.description}}</span>
      {{/if}}
    </div>
  </template>
}
