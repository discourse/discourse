import Component from "@glimmer/component";
import { on } from "@ember/modifier";

/**
 * @class DSheetHandle
 * @classdesc Interactive handle for d-sheet; supports present, dismiss, and step actions.
 * @component DSheetHandle
 * @param {Object} sheet - Sheet controller instance
 * @param {string} [action="step"] - Action to perform: "dismiss", "step", or "present"
 */
export default class Handle extends Component {
  /**
   * Effective action; defaults to "step" when not provided.
   *
   * @returns {string}
   */
  get action() {
    return this.args.action ?? "step";
  }

  /**
   * Whether the handle is disabled. Disabled when only one detent exists and action is not "dismiss".
   *
   * @returns {boolean}
   */
  get isDisabled() {
    const detents = this.args.sheet?.detents;
    return detents?.length === 1 && this.action !== "dismiss";
  }

  /**
   * Accessible fallback text when no block content is yielded.
   *
   * @returns {string}
   */
  get defaultText() {
    return this.action === "dismiss" ? "Dismiss" : "Cycle";
  }

  /**
   * Click handler derived from the selected action.
   *
   * @returns {Function|null}
   */
  get clickHandler() {
    switch (this.action) {
      case "dismiss":
        return this.args.sheet?.close;
      case "step":
        return this.args.sheet?.step;
      case "present":
        return this.args.sheet?.open;
      default:
        return null;
    }
  }

  <template>
    <button
      type="button"
      data-d-sheet="touch-target-expander handle"
      disabled={{this.isDisabled}}
      aria-expanded={{@sheet.isPresented}}
      aria-controls={{@sheet.id}}
      {{on "click" this.clickHandler}}
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
