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
  nodeOutputFirstJsonPath,
  nodeOutputLinkedItemJsonPath,
  outputIndexForConnection,
  previousNodeForConnection,
  schemaFieldsForItems,
  schemaFieldsForNodeInput,
} from "../../../lib/workflows/data-schema";
import buildExpressionExtensions from "../../../lib/workflows/expression-extensions";
import ExpressionPreview from "../variable/expression-preview";
import VariableInput from "../variable/input";
import ReferencePropertyPicker from "../variable/reference-property-picker";

const REFERENCE_PICKER_IDENTIFIER = "workflows-reference-picker";

export default class ExpressionInput extends Component {
  @service siteSettings;
  @service workflowsNodeTypes;
  @service menu;

  @tracked isFocused = false;
  @tracked segments = [];
  wrapperElement = null;
  #focusOutTimer = null;
  #pickerDismiss = null;
  #pickerEditorElement = null;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#focusOutTimer);
    this.#closeReferencePicker();
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
    // Pinned sample data, falling back to the last run.
    const ancestorNodes = node
      ? ancestorOutputNodes(node, graph).map((ancestor) => {
          const items =
            session?.outputItemsForNode(ancestor.node, ancestor.outputIndex) ||
            [];
          const prefix =
            items.length === 1
              ? nodeOutputFirstJsonPath(ancestor.node.name, {
                  outputIndex: ancestor.outputIndex,
                })
              : nodeOutputLinkedItemJsonPath(ancestor.node.name);
          return {
            node: ancestor.node,
            fields: schemaFieldsForItems(items, { prefix }),
          };
        })
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
      onOpenReferencePicker: this.openReferencePicker,
    });
  }

  @action
  openReferencePicker({ trigger, properties, current, onSelect, onEdit }) {
    this.menu.show(trigger, {
      identifier: REFERENCE_PICKER_IDENTIFIER,
      component: ReferencePropertyPicker,
      placement: "bottom-start",
      data: {
        properties,
        current,
        onSelect: onSelect
          ? (name) => {
              this.#closeReferencePicker();
              onSelect(name);
            }
          : null,
        onEdit: onEdit
          ? () => {
              this.#closeReferencePicker();
              onEdit();
            }
          : null,
      },
    });
    this.#armPickerDismiss();
  }

  // CodeMirror swallows pointerdowns before float-kit's outside-click detector
  // sees them, so dismiss on a capture listener instead.
  #armPickerDismiss() {
    this.#teardownPickerDismiss();
    const editor = this.wrapperElement?.querySelector(".cm-editor");
    if (!editor) {
      return;
    }
    this.#pickerEditorElement = editor;
    this.#pickerDismiss = () => this.#closeReferencePicker();
    editor.addEventListener("pointerdown", this.#pickerDismiss, {
      capture: true,
    });
  }

  #teardownPickerDismiss() {
    if (this.#pickerEditorElement && this.#pickerDismiss) {
      this.#pickerEditorElement.removeEventListener(
        "pointerdown",
        this.#pickerDismiss,
        { capture: true }
      );
    }
    this.#pickerEditorElement = null;
    this.#pickerDismiss = null;
  }

  #closeReferencePicker() {
    this.menu.close(REFERENCE_PICKER_IDENTIFIER);
    this.#teardownPickerDismiss();
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
