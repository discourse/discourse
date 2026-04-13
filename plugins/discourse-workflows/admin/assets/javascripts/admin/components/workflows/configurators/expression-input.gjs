import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import discourseLater from "discourse/lib/later";
import ExpressionPreview from "../variable/expression-preview";
import VariableInput from "../variable/input";

export default class ExpressionInput extends Component {
  @service workflowsNodeTypes;

  @tracked isFocused = false;
  wrapperElement = null;
  editorApi = null;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this._focusOutTimer);
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
  handleChange(value) {
    this.args.field.set(`=${value}`);
  }

  @action
  handleFocusIn() {
    cancel(this._focusOutTimer);
    this.isFocused = true;
  }

  @action
  handleFocusOut() {
    this._focusOutTimer = discourseLater(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      // Keep open if focus is in the editor or the result tooltip
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

  @action
  handleEditorReady(api) {
    this.editorApi = api;
  }

  @action
  handleSegmentsResolved(segments, evaluatedTemplate) {
    if (!this.editorApi) {
      return;
    }

    const { view, markInvalidExpressions, clearInvalidExpressions } =
      this.editorApi;

    // Discard stale results if the doc changed since evaluation
    if (evaluatedTemplate && evaluatedTemplate !== view.state.doc.toString()) {
      return;
    }

    // Use backend-provided from/to positions — no client-side re-parsing.
    // Pass all resolved segments so the editor can color-code each
    // expression by its state (valid, invalid, warning, pending).
    const resolvedRanges = segments.filter(
      (seg) => seg.kind === "resolved" && seg.from !== undefined
    );

    if (resolvedRanges.length) {
      markInvalidExpressions(view, resolvedRanges);
    } else {
      clearInvalidExpressions(view);
    }
  }

  <template>
    <div {{didInsert this.registerWrapper}}>
      <VariableInput
        @value={{this.displayValue}}
        @onChange={{this.handleChange}}
        @onFocusIn={{this.handleFocusIn}}
        @onFocusOut={{this.handleFocusOut}}
        @onEditorReady={{this.handleEditorReady}}
      />
    </div>
    <ExpressionPreview
      @value={{this.displayValue}}
      @workflowId={{this.workflowsNodeTypes.workflowId}}
      @nodeId={{this.workflowsNodeTypes.editingNode.id}}
      @trigger={{this.triggerElement}}
      @visible={{this.isFocused}}
      @onSegmentsResolved={{this.handleSegmentsResolved}}
    />
  </template>
}
