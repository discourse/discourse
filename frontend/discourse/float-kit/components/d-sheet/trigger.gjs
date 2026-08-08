import { on } from "@ember/modifier";
import DButton from "discourse/ui-kit/d-button";
import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import outletAnimationModifier from "./outlet-animation-modifier";
import SheetActionBase from "./sheet-action-base";

export default class Trigger extends SheetActionBase {
  get ariaHasPopup() {
    const role = this.sheet?.role;
    const isDialogRole = role === "dialog" || role === "alertdialog";
    return isDialogRole && this.actionType === "present" ? "dialog" : undefined;
  }

  get ariaExpanded() {
    const actionType = this.actionType;
    if (actionType === "present" || actionType === "dismiss") {
      return this.sheet?.isPresented ? "true" : "false";
    }
    return undefined;
  }

  get root() {
    return this.targetRoot ?? this.sheet?.rootComponent;
  }

  beforeExecuteAction(event) {
    if (this.actionType === "present") {
      this.sheet?.setPreviouslyFocusedElement(event.currentTarget);
    }
  }

  executeAction() {
    const root = this.root;

    switch (this.actionType) {
      case "dismiss":
        if (root) {
          root.dismiss();
        } else {
          this.sheet?.requestDismiss();
        }
        break;
      case "step":
        this.executeStepAction();
        break;
      case "present":
      default:
        if (root) {
          root.present();
        } else {
          this.sheet?.requestPresent();
        }
        break;
    }
  }

  <template>
    <DButton
      aria-haspopup={{this.ariaHasPopup}}
      aria-controls={{this.sheetId}}
      aria-expanded={{this.ariaExpanded}}
      {{on "click" this.handleClick}}
      {{outletAnimationModifier this.sheet @travelAnimation @stackingAnimation}}
      class="btn-default"
      ...attributes
      {{mergeSheetAttributes
        "outlet"
        "trigger"
        "touch-target-expander"
        (if this.sheet.isStackAnimating "animating")
      }}
    >
      {{yield}}
    </DButton>
  </template>
}
