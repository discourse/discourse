import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import discourseLater from "discourse/lib/later";
import {
  ancestorOutputNodes,
  inputConnectionsForNode,
  inputIndexForConnection,
  inputSummaryForNode,
  nodeOutputJsonPath,
  outputIndexForConnection,
  previousNodeForConnection,
  schemaFieldsForNodeInput,
  schemaFieldsForNodeOutput,
} from "../../../lib/workflows/data-schema";
import buildExpressionExtensions from "../../../lib/workflows/expression-extensions";
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
    const session = this.args.session;
    const node = session?.editingNode;
    const graph = {
      nodes: session?.graphNodes || [],
      connections: session?.graphConnections || [],
      nodeTypes: this.workflowsNodeTypes.nodeTypes || [],
    };
    const itemPrefix =
      this.workflowsNodeTypes.expressionContext.item_prefix || "$json";
    const runData = session?.lastExecutionRunData || {};
    const previousConnection = node
      ? inputConnectionsForNode(node, graph)[0]
      : null;
    const previousNode = previousNodeForConnection(previousConnection, graph);
    const currentInputIndex = previousConnection
      ? inputIndexForConnection(previousConnection)
      : 0;
    const currentInputSummary = node
      ? inputSummaryForNode(runData, node.name, currentInputIndex, {
          node,
          sourceNode: previousNode,
          outputIndex: previousConnection
            ? outputIndexForConnection(previousConnection)
            : 0,
        })
      : null;
    let inputFields = [];
    if (currentInputSummary) {
      inputFields = schemaFieldsForNodeInput(runData, node.name, {
        inputIndex: currentInputIndex,
        node,
        sourceNode: previousNode,
        outputIndex: previousConnection
          ? outputIndexForConnection(previousConnection)
          : 0,
        prefix: itemPrefix,
      });
    }
    const ancestorNodes = node
      ? ancestorOutputNodes(node, graph).map((ancestor) => ({
          node: ancestor.node,
          fields: schemaFieldsForNodeOutput(runData, ancestor.node.name, {
            outputIndex: ancestor.outputIndex,
            node: ancestor.node,
            prefix: nodeOutputJsonPath(runData, ancestor.node.name, {
              outputIndex: ancestor.outputIndex,
              node: ancestor.node,
            }),
          }),
        }))
      : [];

    return buildExpressionExtensions(cmParams, {
      inputFields,
      ancestorNodes,
      siteSettings: this.siteSettings,
      workflowVars: this.workflowsNodeTypes.workflowVars,
      nodes: graph.nodes,
      itemPrefix,
      workflowId: session?.workflowId,
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
