import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";
import SheetActionBase from "./sheet-action-base";

export default class Handle extends SheetActionBase {
  get defaultAction() {
    return "step";
  }

  get isDisabled() {
    const detents = this.sheet?.detents;
    return detents?.length === 1 && this.actionType !== "dismiss";
  }

  get defaultText() {
    return i18n(
      this.actionType === "dismiss" ? "d_sheet.dismiss" : "d_sheet.cycle"
    );
  }

  get isPresented() {
    return this.sheet?.isPresented ?? false;
  }

  get root() {
    return this.targetRoot ?? this.sheet?.rootComponent;
  }

  executeAction() {
    switch (this.actionType) {
      case "dismiss":
        if (this.root) {
          this.root.dismiss();
        } else {
          this.sheet?.requestDismiss();
        }
        break;
      case "step":
        this.executeStepAction();
        break;
    }
  }

  <template>
    <button
      type="button"
      data-d-sheet="touch-target-expander handle"
      disabled={{this.isDisabled}}
      aria-expanded={{this.isPresented}}
      aria-controls={{this.sheetId}}
      {{on "click" this.handleClick}}
      ...attributes
    >
      {{#if (has-block)}}
        {{yield}}
      {{else}}
        <span class="sr-only">{{this.defaultText}}</span>
      {{/if}}
    </button>
  </template>
}
