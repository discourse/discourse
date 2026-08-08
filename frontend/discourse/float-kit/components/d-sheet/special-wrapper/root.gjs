import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { capabilities } from "discourse/services/capabilities";
import mergeSheetAttributes from "../../../modifiers/merge-sheet-attributes";
import { scrollTrapModifier } from "../scroll-trap-modifier";

export default class DSheetSpecialWrapperRoot extends Component {
  active = capabilities.isWebKit;

  get perpendicularAxis() {
    const tracks = this.args.sheet?.tracks;
    return tracks === "left" || tracks === "right" || tracks === "horizontal"
      ? "vertical"
      : "horizontal";
  }

  <template>
    <@tag
      {{scrollTrapModifier this.active}}
      ...attributes
      {{mergeSheetAttributes
        "scroll-trap-root"
        "special-wrapper-root"
        (if this.perpendicularAxis (concat "scroll-" this.perpendicularAxis))
        (if this.active "scroll-trap-active" "scroll-trap-inactive")
        "scroll-trap-optimised"
      }}
    >
      {{yield}}
    </@tag>
  </template>
}
