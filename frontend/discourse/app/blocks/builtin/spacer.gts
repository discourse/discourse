import Component from "@glimmer/component";
import { type TrustedHTML, trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { i18n } from "discourse-i18n";

interface SpacerSignature {
  Args: {
    size?: number;
  };
}

@block("spacer", {
  thumbnail: () => import("discourse/blocks/thumbnails/spacer"),
  displayName: "Spacer",
  icon: "arrows-up-down",
  category: "Layout",
  description: "An empty vertical or horizontal gap.",
  args: {
    size: {
      type: "number",
      default: 1,
      min: 0.25,
      max: 8,
      ui: { label: i18n("blocks.builtin.spacer.size") },
    },
  },
})
export default class Spacer extends Component<SpacerSignature> {
  /**
   * Inline `height` / `width` declaration so the spacer occupies the
   * requested size on both axes (works for both horizontal and vertical
   * gaps, depending on the parent layout).
   */
  get style(): TrustedHTML {
    const size = this.args.size ?? 1;
    return trustHTML(`height: ${size}rem; width: ${size}rem;`);
  }

  <template>
    <div class="d-block-spacer" style={{this.style}}></div>
  </template>
}
