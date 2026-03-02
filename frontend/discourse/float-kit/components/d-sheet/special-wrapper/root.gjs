import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { capabilities } from "discourse/services/capabilities";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";
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
      data-d-sheet={{concatClass
        "scroll-trap-root"
        "special-wrapper-root"
        (if this.perpendicularAxis (concat "scroll-" this.perpendicularAxis))
        (if this.active "scroll-trap-active" "scroll-trap-inactive")
        "scroll-trap-optimised"
      }}
      {{scrollTrapModifier this.active}}
      ...attributes
    >
      {{yield}}
    </@tag>
  </template>
}
