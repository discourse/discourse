import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import {
  getNodeIcons,
  nodeDescription,
  nodeLabel,
} from "../../../lib/workflows/node-utils";

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

export default class WorkflowNode extends Component {
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

  get isManualTrigger() {
    return this.data.type === "trigger:manual";
  }

  get nodeStyle() {
    return htmlSafe(
      `width: ${this.args.node.width}px; height: ${this.args.node.height}px`
    );
  }

  get iconStyle() {
    return htmlSafe(`color: ${this.iconInfo?.color}`);
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding }}
    <div
      class="workflow-rete-node
        {{if this.isTrigger ' --trigger'}}
        {{if this.isBranching ' --branching'}}
        {{if @node.selected ' --selected'}}"
      style={{this.nodeStyle}}
      data-client-id={{this.data.clientId}}
    >
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

      <div class="workflow-rete-node__body">
        <div class="workflow-rete-node__title-row">
          {{#if this.iconInfo.icon}}
            <span class="workflow-rete-node__icon" style={{this.iconStyle}}>
              {{icon this.iconInfo.icon}}
            </span>
          {{/if}}
          <span class="workflow-rete-node__label">{{this.label}}</span>
        </div>

        {{#if this.description}}
          <span
            class="workflow-rete-node__description"
          >{{this.description}}</span>
        {{/if}}

        {{#if this.isManualTrigger}}
          <button
            type="button"
            class="workflow-rete-node__delete-btn workflow-rete-node__run-btn"
            {{on "pointerdown" this.stopPropagation}}
            {{on "click" this.handleManualTrigger}}
          >
            {{icon "play"}}
          </button>
        {{/if}}

        <button
          type="button"
          class="workflow-rete-node__delete-btn"
          {{on "pointerdown" this.stopPropagation}}
          {{on "click" this.handleDelete}}
        >
          {{icon "trash-can"}}
        </button>
      </div>

      <div class="workflow-rete-node__outputs">
        {{#each this.outputKeys as |key|}}
          <div
            class="workflow-rete-node__socket --output
              {{if (eq key 'loop') ' --loop'}}"
            data-socket-key={{key}}
            {{didInsert
              (fn @onSocketRendered @node.id "output" key @node.outputs)
            }}
          >
            {{#if this.isBranching}}
              <span
                class="workflow-rete-node__port-pill
                  {{if (isPositivePort key) ' --positive' ' --negative'}}"
              >
                {{portLabel this.data.type key}}
              </span>
            {{/if}}
          </div>
        {{/each}}
      </div>
    </div>
  </template>
}
