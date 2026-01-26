import { on } from "@ember/modifier";
import SheetActionBase from "./sheet-action-base";

/**
 * Interactive handle for d-sheet; supports dismiss and step actions.
 *
 * @component DSheetHandle
 * @param {string} forComponent - ID of the Root to associate with (uses Root's componentId)
 * @param {Object} sheet - Sheet controller instance (alternative to forComponent)
 * @param {string|Object} action - Action to perform:
 *   - "dismiss": closes the sheet
 *   - "step" (default): steps to next detent (upward, cycles)
 *   - { type: "step", direction?: "up"|"down", detent?: number }: step with options
 * @param {Object|Function} onPress - Press behavior configuration:
 *   - { forceFocus?: boolean, runAction?: boolean }
 *   - Or function receiving event with changeDefault method
 *   Default: { forceFocus: true, runAction: true }
 */
export default class Handle extends SheetActionBase {
  get defaultAction() {
    return "step";
  }

  /**
   * Whether the handle is disabled.
   * Disabled when only one detent exists and action is not "dismiss".
   *
   * @type {boolean}
   */
  get isDisabled() {
    const detents = this.sheet?.detents;
    return detents?.length === 1 && this.actionType !== "dismiss";
  }

  /**
   * Accessible fallback text when no block content is yielded.
   *
   * @type {string}
   */
  get defaultText() {
    return this.actionType === "dismiss" ? "Dismiss" : "Cycle";
  }

  /**
   * Whether the sheet is presented for aria-expanded.
   *
   * @type {boolean}
   */
  get isPresented() {
    return this.sheet?.isPresented ?? false;
  }

  /**
   * Execute the configured action on the sheet.
   */
  executeAction() {
    switch (this.actionType) {
      case "dismiss":
        this.sheet?.close();
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
