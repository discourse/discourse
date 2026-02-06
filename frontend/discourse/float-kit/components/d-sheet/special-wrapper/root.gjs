import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import concatClass from "discourse/helpers/concat-class";
import { capabilities } from "discourse/services/capabilities";
import outletAnimationModifier from "../outlet-animation-modifier";
import { scrollTrapModifier } from "../scroll-trap-modifier";

/**
 * Scroll-trap root for special layouts like Toast.
 * When used with Content's asChild pattern, this component merges
 * the content attributes with scroll-trap functionality.
 *
 * @component DSheetSpecialWrapperRoot
 * @param {import("../controller").default} sheet - The sheet controller instance
 * @param {Object} contentAttrs - Merged content attributes from Content's asChild pattern
 * @param {string} [contentAttrs.dataDSheet] - Content data-d-sheet attributes to merge
 * @param {Function} [contentAttrs.registerContent] - Content registration callback
 * @param {Object} [contentAttrs.travelAnimation] - Travel animation configuration
 * @param {Object} [contentAttrs.stackingAnimation] - Stacking animation configuration
 */
export default class DSheetSpecialWrapperRoot extends Component {
  /**
   * Whether the scroll trap is active, based on WebKit browser detection.
   * Only WebKit browsers require the scroll trap optimization.
   *
   * @type {boolean}
   */
  active = capabilities.isWebKit;

  /**
   * Calculates the perpendicular axis based on the sheet's travel axis.
   * Top/bottom tracks have vertical travel, so perpendicular is horizontal.
   * Left/right/horizontal tracks have horizontal travel, so perpendicular is vertical.
   *
   * @returns {"vertical"|"horizontal"} The perpendicular axis direction
   */
  get perpendicularAxis() {
    const tracks = this.args.sheet?.tracks;
    return tracks === "left" || tracks === "right" || tracks === "horizontal"
      ? "vertical"
      : "horizontal";
  }

  <template>
    <div
      data-d-sheet={{concatClass
        @contentAttrs.dataDSheet
        "scroll-trap-root"
        "special-wrapper-root"
        (if this.perpendicularAxis (concat "scroll-" this.perpendicularAxis))
        (if this.active "scroll-trap-active" "scroll-trap-inactive")
        "scroll-trap-optimised"
      }}
      {{scrollTrapModifier this.active}}
      {{didInsert @contentAttrs.registerContent}}
      {{outletAnimationModifier
        @sheet
        @contentAttrs.travelAnimation
        @contentAttrs.stackingAnimation
      }}
      ...attributes
    >
      {{yield}}
    </div>
  </template>
}
