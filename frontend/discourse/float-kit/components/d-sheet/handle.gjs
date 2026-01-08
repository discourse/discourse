import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { service } from "@ember/service";

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
export default class Handle extends Component {
  @service sheetRegistry;

  /**
   * Handle click event with onPress behavior processing.
   *
   * @param {MouseEvent} event
   */
  handleClick = (event) => {
    const defaultBehavior = { forceFocus: true, runAction: true };
    let behavior = { ...defaultBehavior };

    const onPress = this.args.onPress;
    if (onPress) {
      if (typeof onPress === "function") {
        const customEvent = {
          nativeEvent: event,
          ...behavior,
          changeDefault(changes) {
            behavior = { ...behavior, ...changes };
            Object.assign(this, changes);
          },
        };
        onPress(customEvent);
      } else {
        behavior = { ...defaultBehavior, ...onPress };
      }
    }

    if (behavior.forceFocus) {
      event.currentTarget?.focus({ preventScroll: true });
    }

    if (!behavior.runAction) {
      return;
    }

    this.executeAction();
  };

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
   * The raw action prop value. Defaults to "step" for Handle.
   *
   * @type {string|Object}
   */
  get triggerAction() {
    return this.args.action ?? "step";
  }

  /**
   * The action type extracted from the action prop.
   *
   * @type {string}
   */
  get actionType() {
    const action = this.triggerAction;
    return typeof action === "object" ? action.type : action;
  }

  /**
   * The step direction when action is { type: "step", direction: ... }.
   *
   * @type {string}
   */
  get stepDirection() {
    const action = this.triggerAction;
    return typeof action === "object" ? (action.direction ?? "up") : "up";
  }

  /**
   * The target detent when action is { type: "step", detent: ... }.
   *
   * @type {number|undefined}
   */
  get stepDetent() {
    const action = this.triggerAction;
    return typeof action === "object" ? action.detent : undefined;
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
   * The sheet ID for aria-controls.
   *
   * @type {string|undefined}
   */
  get sheetId() {
    return this.sheet?.id;
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
        if (this.stepDetent !== undefined) {
          this.sheet?.stepToDetent(this.stepDetent);
        } else if (this.stepDirection === "down") {
          this.sheet?.stepDown();
        } else {
          this.sheet?.step();
        }
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
