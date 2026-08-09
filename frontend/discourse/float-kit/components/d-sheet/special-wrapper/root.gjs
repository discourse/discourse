import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { capabilities } from "discourse/services/capabilities";
import mergeSheetAttributes from "../../../modifiers/merge-sheet-attributes";
import { scrollTrapModifier } from "../scroll-trap-modifier";

const DefaultTag = <template>
  <div ...attributes>{{yield}}</div>
</template>;

export default class DSheetSpecialWrapperRoot extends Component {
  active = capabilities.isWebKit;

  get tag() {
    return this.args.tag ?? DefaultTag;
  }

  get perpendicularAxis() {
    const tracks = this.args.sheet?.tracks;
    return tracks === "left" || tracks === "right" || tracks === "horizontal"
      ? "vertical"
      : "horizontal";
  }

  <template>
    <this.tag
      {{scrollTrapModifier this.active}}
      ...attributes
      {{mergeSheetAttributes
        "scroll-trap-root"
        "special-wrapper-root"
        "scroll-trap-marker"
        "scroll-trap-end"
        (if this.perpendicularAxis (concat "scroll-" this.perpendicularAxis))
        (if this.active "scroll-trap-active" "scroll-trap-inactive")
        "scroll-trap-optimised"
      }}
    >
      {{yield}}
    </this.tag>
  </template>
}
