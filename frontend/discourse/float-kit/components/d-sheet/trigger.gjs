import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import SheetActionBase from "./sheet-action-base";

/**
 * Trigger button for controlling a sheet.
 *
 * @component Trigger
 * @param {string} forComponent - ID of the Root to associate with (uses Root's componentId)
 * @param {Object} sheet - The sheet controller instance (alternative to forComponent)
 * @param {string|Object} action - Action to perform:
 *   - "present" (default): opens the sheet
 *   - "dismiss": closes the sheet
 *   - "step": steps to next detent (upward, cycles)
 *   - { type: "step", direction?: "up"|"down", detent?: number }: step with options
 * @param {Object|Function} onPress - Press behavior configuration:
 *   - { forceFocus?: boolean, runAction?: boolean }
 *   - Or function receiving event with changeDefault method
 *   Default: { forceFocus: true, runAction: true }
 */
export default class Trigger extends SheetActionBase {
  get ariaHasPopup() {
    const role = this.sheet?.role;
    const isDialogRole = role === "dialog" || role === "alertdialog";
    return isDialogRole && this.actionType === "present" ? "dialog" : undefined;
  }

  /**
   * aria-expanded attribute value.
   * Only relevant for present/dismiss actions.
   *
   * @type {boolean|undefined}
   */
  get ariaExpanded() {
    const actionType = this.actionType;
    if (actionType === "present" || actionType === "dismiss") {
      return this.sheet?.isPresented ?? false;
    }
    return undefined;
  }

  /**
   * The Root component - either from forComponent lookup or from sheet's reference.
   *
   * @type {Object|undefined}
   */
  get root() {
    return this.targetRoot ?? this.sheet?.rootComponent;
  }

  /**
   * Execute the configured action on the sheet.
   * Uses Root's present()/dismiss() methods for controlled/uncontrolled handling.
   */
  executeAction() {
    const root = this.root;

    switch (this.actionType) {
      case "dismiss":
        if (root) {
          root.dismiss();
        } else {
          this.sheet?.close();
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
          this.sheet?.open();
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
      class="btn-default"
      ...attributes
    >
      {{yield}}
    </DButton>
  </template>
}
