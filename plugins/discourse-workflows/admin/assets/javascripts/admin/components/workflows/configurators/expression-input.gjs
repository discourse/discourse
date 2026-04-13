import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import discourseLater from "discourse/lib/later";
import buildWorkflowExtension from "../../../lib/workflows/codemirror-extension";
import {
  resolveAllAncestors,
  resolvePreviousOutput,
} from "../../../lib/workflows/graph-traversal";
import ExpressionPreview from "../variable/expression-preview";
import VariableInput from "../variable/input";

export default class ExpressionInput extends Component {
  @service siteSettings;
  @service workflowsNodeTypes;

  @tracked isFocused = false;
  @tracked segments = [];
  wrapperElement = null;
  #focusOutTimer = null;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#focusOutTimer);
  }

  get displayValue() {
    const val = this.args.field.value;
    if (typeof val === "string" && val.startsWith("=")) {
      return val.slice(1);
    }
    return val ?? "";
  }

  get triggerElement() {
    return (
      this.wrapperElement?.querySelector(".workflows-variable-input") ||
      this.wrapperElement
    );
  }

  @action
  buildExtensions(cmParams) {
    const node = this.workflowsNodeTypes.editingNode;
    const graph = {
      nodes: this.workflowsNodeTypes.graphNodes || [],
      connections: this.workflowsNodeTypes.graphConnections || [],
      nodeTypes: this.workflowsNodeTypes.nodeTypes || [],
    };
    const itemPrefix =
      this.workflowsNodeTypes.expressionContext.item_prefix || "$json";

    return buildWorkflowExtension(cmParams, {
      inputFields: node ? resolvePreviousOutput(node, graph) : [],
      ancestorNodes: node ? resolveAllAncestors(node, graph) : [],
      siteSettings: this.siteSettings,
      workflowVars: this.workflowsNodeTypes.workflowVars,
      nodes: graph.nodes,
      itemPrefix,
      workflowId: this.workflowsNodeTypes.workflowId,
      nodeId: node?.id,
      onSegmentsResolved: (segs) => (this.segments = segs),
    });
  }

  @action
  handleChange(value) {
    this.args.field.set(`=${value}`);
  }

  @action
  handleFocusIn() {
    cancel(this.#focusOutTimer);
    this.isFocused = true;
  }

  @action
  handleFocusOut() {
    this.#focusOutTimer = discourseLater(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      const editor = this.wrapperElement?.querySelector(".cm-editor");
      if (editor?.contains(document.activeElement)) {
        return;
      }
      const tooltip = document.querySelector(
        '[data-identifier="expression-preview"]'
      );
      if (tooltip?.contains(document.activeElement)) {
        return;
      }
      this.isFocused = false;
    }, 150);
  }

  @action
  registerWrapper(element) {
    this.wrapperElement = element;
  }

  <template>
    <div {{didInsert this.registerWrapper}}>
      <VariableInput
        @value={{this.displayValue}}
        @onChange={{this.handleChange}}
        @extensions={{this.buildExtensions}}
        @onFocusIn={{this.handleFocusIn}}
        @onFocusOut={{this.handleFocusOut}}
      />
    </div>
    <ExpressionPreview
      @segments={{this.segments}}
      @trigger={{this.triggerElement}}
      @visible={{this.isFocused}}
    />
  </template>
}
