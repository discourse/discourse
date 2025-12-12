import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import concatClass from "discourse/helpers/concat-class";

/**
 * Backdrop component for d-sheet.
 *
 * @component Backdrop
 * @param {Object} sheet - The sheet controller instance
 * @param {boolean} swipeable - Whether backdrop responds to click/swipe (default: true)
 * @param {Object|Function} travelAnimation - Custom travel animation config
 *   Default: ({ progress }) => Math.min(progress * 0.33, 0.33)
 *   Set to { opacity: null } to disable
 */
export default class Backdrop extends Component {
  get swipeable() {
    return this.args.swipeable ?? true;
  }

  @action
  registerBackdropElement(element) {
    this.args.sheet.registerBackdrop(element, this.args.travelAnimation);
  }

  <template>
    {{#if @sheet}}
      <div
        data-d-sheet={{concatClass
          "backdrop"
          (unless this.swipeable "no-pointer-events")
        }}
        {{didInsert this.registerBackdropElement}}
      ></div>
    {{/if}}
  </template>
}
