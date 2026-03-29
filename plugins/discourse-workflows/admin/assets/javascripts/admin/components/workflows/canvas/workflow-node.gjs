import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import {
  getNodeIcons,
  nodeDescription,
  nodeLabel,
} from "../../../lib/workflows/node-utils";
import CanvasHoverToolbar from "./hover-toolbar";

function portLabel(type, key) {
  if (type === "condition:filter") {
    return key === "true"
      ? i18n("discourse_workflows.executions.statuses.kept")
      : i18n("discourse_workflows.executions.statuses.rejected");
  }
  return key;
}

function isPositivePort(key) {
  return key === "true" || key === "loop" || key === "done";
}

function isOutputConnected(connectedOutputKeys, key) {
  return connectedOutputKeys?.has(key) ?? false;
}

export default class WorkflowNode extends Component {
  @service router;

  stopPropagation = (e) => e.stopPropagation();

  handleOutputAddNode = (key, e) => {
    e.stopPropagation();
    e.preventDefault();
    this.args.onOutputAddNode?.(this.data.clientId, key);
  };

  handleDelete = (e) => {
    e.stopPropagation();
    e.preventDefault();
    this.args.onDelete?.(this.data.clientId);
  };

  handleManualTrigger = (e) => {
    e.stopPropagation();
    this.args.onManualTrigger?.(this.data.clientId);
  };

  get data() {
    return this.args.node.workflowData;
  }

  get isTrigger() {
    return this.data.type?.startsWith("trigger:");
  }

  get isBranching() {
    return Object.keys(this.args.node.outputs).length > 1;
  }

  get iconInfo() {
    return getNodeIcons()[this.data.type];
  }

  get label() {
    return nodeLabel(this.data);
  }

  get description() {
    return nodeDescription(this.data);
  }

  get outputKeys() {
    return Object.keys(this.args.node.outputs);
  }

  get isManuallyTriggerable() {
    return this.args.manuallyTriggerableTypes?.has(this.data.type) ?? false;
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
    const key = this.iconInfo?.colorKey;
    const color = key
      ? `var(--workflow-node-color-${key})`
      : "var(--primary-medium)";
    return trustHTML(`--node-icon-color: ${color}`);
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding }}
    <div
      class="workflow-rete-node
        {{if this.isTrigger ' --trigger'}}
        {{if this.isBranching ' --branching'}}
        {{if @node.selected ' --selected'}}"
      data-client-id={{this.data.clientId}}
    >
      <div class="workflow-rete-node__icon-row">
        {{#if @node.inputs.input}}
          <div
            class="workflow-rete-node__socket --input"
            {{didInsert
              (fn
                @onSocketRendered
                @node.id
                "input"
                "input"
                @node.inputs.input.socket
              )
            }}
          />
        {{/if}}

        <div
          class="workflow-rete-node__icon-block"
          style={{this.iconBlockStyle}}
        >
          <CanvasHoverToolbar @hoverSelector=".workflow-rete-node">
            {{#if this.isManuallyTriggerable}}
              <button
                type="button"
                class="workflow-canvas-toolbar__btn --success
                  {{unless @workflowEnabled '--disabled'}}"
                disabled={{unless @workflowEnabled true}}
                {{on "pointerdown" this.stopPropagation}}
                {{on "click" this.handleManualTrigger}}
              >
                {{icon "play"}}
              </button>
            {{/if}}
            {{#if this.dataTableId}}
              <button
                type="button"
                class="workflow-canvas-toolbar__btn"
                {{on "pointerdown" this.stopPropagation}}
                {{on "click" this.handleEditDataTable}}
              >
                {{icon "eye"}}
              </button>
            {{/if}}
            <button
              type="button"
              class="workflow-canvas-toolbar__btn"
              {{on "pointerdown" this.stopPropagation}}
              {{on "click" this.handleDelete}}
            >
              {{icon "trash-can"}}
            </button>
          </CanvasHoverToolbar>

          {{#if this.iconInfo.icon}}
            <span class="workflow-rete-node__icon">
              {{icon this.iconInfo.icon}}
            </span>
          {{/if}}
        </div>

        <div class="workflow-rete-node__outputs">
          {{#each this.outputKeys as |key|}}
            <div class="workflow-rete-node__output-row">
              <div
                class="workflow-rete-node__socket --output
                  {{if (eq key 'loop') ' --loop'}}"
                data-socket-key={{key}}
                {{didInsert
                  (fn @onSocketRendered @node.id "output" key @node.outputs)
                }}
              />
              {{#if this.isBranching}}
                <span
                  class="workflow-rete-node__port-pill
                    {{if (isPositivePort key) ' --positive' ' --negative'}}"
                >
                  {{portLabel this.data.type key}}
                </span>
              {{/if}}
              {{#unless (isOutputConnected @connectedOutputKeys key)}}
                <button
                  type="button"
                  class="workflow-rete-node__output-add-btn"
                  {{on "pointerdown" this.stopPropagation}}
                  {{on "click" (fn this.handleOutputAddNode key)}}
                >
                  {{icon "plus"}}
                </button>
              {{/unless}}
            </div>
          {{/each}}
        </div>
      </div>

      <span class="workflow-rete-node__label">{{this.label}}</span>

      {{#if this.description}}
        <span
          class="workflow-rete-node__description"
        >{{this.description}}</span>
      {{/if}}
    </div>
  </template>
}
