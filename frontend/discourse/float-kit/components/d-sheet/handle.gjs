import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";
import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import outletAnimationModifier from "./outlet-animation-modifier";
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

  get ariaExpanded() {
    if (this.actionType === "dismiss") {
      return this.sheet?.isPresented ? "true" : "false";
    }

    return undefined;
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
      disabled={{this.isDisabled}}
      aria-expanded={{this.ariaExpanded}}
      aria-controls={{this.sheetId}}
      {{on "click" this.handleClick}}
      {{outletAnimationModifier this.sheet @travelAnimation @stackingAnimation}}
      ...attributes
      {{mergeSheetAttributes
        "outlet"
        "trigger"
        "touch-target-expander"
        "handle"
        (if this.sheet.isStackAnimating "animating")
      }}
    >
      {{#if (has-block)}}
        {{yield}}
      {{else}}
        <span class="sr-only">{{this.defaultText}}</span>
      {{/if}}
    </button>
  </template>
}
