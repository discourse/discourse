import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { processBehavior } from "discourse/float-kit/lib/behavior-handler";

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
export default class Trigger extends Component {
  @service sheetRegistry;

  /**
   * Handle click event with onPress behavior processing.
   *
   * @param {MouseEvent} event
   */
  @action
  handleClick(event) {
    const behavior = processBehavior({
      nativeEvent: event,
      defaultBehavior: { forceFocus: true, runAction: true },
      handler: this.args.onPress,
    });

    if (behavior.forceFocus) {
      event.currentTarget?.focus({ preventScroll: true });
    }

    if (!behavior.runAction) {
      return;
    }

    this.executeAction();
  }

  /**
   * The Root component found via forComponent lookup.
   *
   * @type {Object|undefined}
   */
  get targetRoot() {
    if (this.args.forComponent) {
      return this.sheetRegistry.getRootByComponentId(this.args.forComponent);
    }
    return undefined;
  }

  /**
   * The sheet controller - from targetRoot or direct @sheet prop.
   *
   * @type {Object|undefined}
   */
  get sheet() {
    return this.targetRoot?.sheet ?? this.args.sheet;
  }

  /**
   * The raw action prop value.
   *
   * @type {string|Object}
   */
  get triggerAction() {
    return this.args.action ?? "present";
  }

  /**
   * The action type extracted from the action prop.
   *
   * @type {string}
   */
  get actionType() {
    return typeof this.triggerAction === "object"
      ? this.triggerAction.type
      : this.triggerAction;
  }

  /**
   * The step direction when action is { type: "step", direction: ... }.
   *
   * @type {string}
   */
  get stepDirection() {
    return typeof this.triggerAction === "object"
      ? (this.triggerAction.direction ?? "up")
      : "up";
  }

  /**
   * The target detent when action is { type: "step", detent: ... }.
   *
   * @type {number|undefined}
   */
  get stepDetent() {
    return typeof this.triggerAction === "object"
      ? this.triggerAction.detent
      : undefined;
  }

  /**
   * aria-haspopup attribute value.
   * Only set to "dialog" for dialog/alertdialog roles with present action.
   *
   * @type {string|undefined}
   */
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
   * The sheet ID for aria-controls.
   *
   * @type {string|undefined}
   */
  get sheetId() {
    return this.sheet?.id;
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
        if (this.stepDetent !== undefined) {
          this.sheet?.stepToDetent(this.stepDetent);
        } else if (this.stepDirection === "down") {
          this.sheet?.stepDown();
        } else {
          this.sheet?.step();
        }
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
