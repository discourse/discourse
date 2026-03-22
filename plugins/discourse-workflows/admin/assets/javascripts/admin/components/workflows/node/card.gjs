import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { loadNodeTypes } from "../../../lib/workflows/node-types";
import { getNodeIcons, nodeLabel } from "../../../lib/workflows/node-utils";
import NodeConfigurator from "./configurator";

const ReplaceTriggerMenu = <template>
  <DMenu
    @identifier="workflows-replace-trigger"
    @icon="arrows-rotate"
    @onShow={{@onShow}}
    class="btn-flat workflows-node-card__replace"
  >
    <:content as |args|>
      <DropdownMenu as |dropdown|>
        {{#each @triggerTypes as |nodeType|}}
          <dropdown.item>
            <DButton
              @action={{fn @onSelect nodeType args.close}}
              @translatedLabel={{i18n
                (concat "discourse_workflows.nodes." nodeType.identifier)
              }}
              class="btn-transparent"
            />
          </dropdown.item>
        {{/each}}
      </DropdownMenu>
    </:content>
  </DMenu>
</template>;

export default class NodeCard extends Component {
  @service modal;

  @tracked isRunning = false;
  @tracked triggerTypes = null;

  get isTrigger() {
    return this.args.node.type?.startsWith("trigger:") && !this.isManualTrigger;
  }

  get typeClass() {
    const type = this.args.node.type;
    if (type === "trigger:manual") {
      return "--condition";
    }
    if (type?.startsWith("trigger:")) {
      return "--trigger";
    }
    if (type?.startsWith("condition:")) {
      return "--condition";
    }
    return "--action";
  }

  get isCondition() {
    return this.args.node.type?.startsWith("condition:");
  }

  get isManualTrigger() {
    return this.args.node.type === "trigger:manual";
  }

  get iconInfo() {
    return getNodeIcons()[this.args.node.type];
  }

  get nodeIcon() {
    return this.iconInfo?.icon;
  }

  get iconStyle() {
    const color = this.iconInfo?.color;
    return color ? trustHTML(`--node-icon-color: ${color}`) : "";
  }

  get summary() {
    return nodeLabel(this.args.node);
  }

  get description() {
    return this.args.node.configuration?.description;
  }

  get triggerType() {
    const triggerNode = this.args.nodes?.find((n) =>
      n.type?.startsWith("trigger:")
    );
    return triggerNode?.type;
  }

  @action
  remove(event) {
    event.stopPropagation();
    this.args.onRemove();
  }

  @action
  edit() {
    this.modal.show(NodeConfigurator, {
      model: {
        node: this.args.node,
        nodes: this.args.nodes,
        connections: this.args.connections,
        triggerType: this.triggerType,
        onSave: this.args.onUpdateConfiguration,
        onRemove: this.args.onRemove,
      },
    });
  }

  @action
  async loadTriggerTypes() {
    if (this.triggerTypes) {
      return;
    }
    const allTypes = await loadNodeTypes();
    this.triggerTypes = allTypes.filter((nt) => nt.category === "trigger");
  }

  @action
  selectTriggerType(nodeType, closeFn) {
    closeFn();
    this.args.onReplaceTrigger(nodeType);
  }

  @action
  async runManual() {
    if (this.isRunning) {
      return;
    }

    this.isRunning = true;
    try {
      await ajax(`/admin/plugins/discourse-workflows/executions.json`, {
        type: "POST",
        data: { trigger_node_id: this.args.node.id },
      });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isRunning = false;
    }
  }

  <template>
    {{#if this.isManualTrigger}}
      <div class="workflows-node-card {{this.typeClass}}">
        <button
          type="button"
          class="workflows-node-card__icon-button --play
            {{if this.isRunning '--running'}}"
          style={{this.iconStyle}}
          disabled={{this.isRunning}}
          {{on "click" this.runManual}}
        >
          {{#if this.isRunning}}
            <div class="spinner small"></div>
          {{else}}
            {{icon "play"}}
          {{/if}}
        </button>
        <button
          type="button"
          class="workflows-node-card__delete"
          {{on "click" this.remove}}
        >{{icon "xmark"}}</button>
        <ReplaceTriggerMenu
          @onShow={{this.loadTriggerTypes}}
          @triggerTypes={{this.triggerTypes}}
          @onSelect={{this.selectTriggerType}}
        />
      </div>
    {{else if this.isCondition}}
      <div class="workflows-node-card {{this.typeClass}}">
        <button
          type="button"
          class="workflows-node-card__icon-button"
          style={{this.iconStyle}}
          {{on "click" this.edit}}
        >
          {{icon this.nodeIcon}}
          {{#if this.description}}
            <span class="workflows-node-card__label">{{this.description}}</span>
          {{/if}}
        </button>
        <button
          type="button"
          class="workflows-node-card__delete"
          {{on "click" this.remove}}
        >{{icon "xmark"}}</button>
      </div>
    {{else}}
      {{! template-lint-disable no-invalid-interactive }}
      <div
        class="workflows-node-card {{this.typeClass}}"
        {{on "click" this.edit}}
      >
        <button
          type="button"
          class="workflows-node-card__delete"
          {{on "click" this.remove}}
        >{{icon "xmark"}}</button>
        {{#if this.isTrigger}}
          <ReplaceTriggerMenu
            @onShow={{this.loadTriggerTypes}}
            @triggerTypes={{this.triggerTypes}}
            @onSelect={{this.selectTriggerType}}
          />
        {{/if}}
        <div class="workflows-node-card__header">
          <span class="workflows-node-card__summary" style={{this.iconStyle}}>
            {{~#if this.nodeIcon}}{{icon this.nodeIcon}} {{/if~}}
            {{this.summary}}
          </span>
          {{#if this.description}}
            <p class="workflows-node-card__description">{{this.description}}</p>
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
