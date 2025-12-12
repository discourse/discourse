import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import concatClass from "discourse/helpers/concat-class";
import { isWebKit } from "../browser-detection";
import { scrollTrapModifier } from "../scroll-trap-modifier";

/**
 * Scroll-trap root for special layouts like Toast.
 *
 * @component DSheetSpecialWrapperRoot
 * @param {Object} sheet - The sheet controller
 */
export default class DSheetSpecialWrapperRoot extends Component {
  @tracked active = false;

  constructor() {
    super(...arguments);
    // Only activate scroll trap on WebKit browsers.
    // Non-WebKit browsers use CSS overscroll-behavior: contain.
    this.active = isWebKit();
  }

  /**
   * Calculates the perpendicular axis based on the sheet's travel axis.
   * Top/bottom tracks have vertical travel, so perpendicular is horizontal.
   * Left/right/horizontal tracks have horizontal travel, so perpendicular is vertical.
   *
   * @returns {string}
   */
  get perpendicularAxis() {
    const tracks = this.args.sheet?.tracks;
    return tracks === "left" || tracks === "right" || tracks === "horizontal"
      ? "vertical"
      : "horizontal";
  }

  <template>
    <div
      class="Sheet-specialWrapperRoot"
      data-d-sheet={{concatClass
        "scroll-trap-root"
        "special-wrapper-root"
        (if
          this.perpendicularAxis
          (concat "scroll-" this.perpendicularAxis)
        )
        (if this.active "scroll-trap-active" "scroll-trap-inactive")
        "scroll-trap-optimised"
      }}
      {{scrollTrapModifier this.active}}
      ...attributes
    >
      {{yield}}
    </div>
  </template>
}
