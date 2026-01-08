import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
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
 * @param {Object} sheet - The sheet controller
 * @param {string} [contentAttrs.dataDSheet] - Content data-d-sheet attributes to merge (from Content asChild)
 * @param {Function} [contentAttrs.registerContent] - Content registration callback (from Content asChild)
 * @param {Object} [contentAttrs.travelAnimation] - Travel animation config (from Content asChild)
 * @param {Object} [contentAttrs.stackingAnimation] - Stacking animation config (from Content asChild)
 */
export default class DSheetSpecialWrapperRoot extends Component {
  @tracked active = false;

  @action
  activate() {
    this.active = capabilities.isWebKit;
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
      data-d-sheet={{concatClass
        @contentAttrs.dataDSheet
        "scroll-trap-root"
        "special-wrapper-root"
        (if this.perpendicularAxis (concat "scroll-" this.perpendicularAxis))
        (if this.active "scroll-trap-active" "scroll-trap-inactive")
        "scroll-trap-optimised"
      }}
      {{scrollTrapModifier this.active}}
      {{didInsert this.activate}}
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
