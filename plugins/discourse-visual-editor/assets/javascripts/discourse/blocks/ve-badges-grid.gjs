// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@block("ve:badges-grid", {
  displayName: "Badges Grid",
  icon: "award",
  category: "Data",
  description: "Placeholder grid of badges (static for now).",
  args: {
    badgeIds: {
      type: "array",
      itemType: "number",
      default: [],
      ui: { label: "Badge IDs" },
    },
  },
  previewArgs: { badgeIds: [] },
})
export default class VEBadgesGrid extends Component {
  get tiles() {
    const ids = this.args.badgeIds?.length ? this.args.badgeIds : [1, 2, 3, 4];
    return ids;
  }

  <template>
    <div class="ve-badges-grid">
      {{#each this.tiles as |id|}}
        <div class="ve-badges-grid__tile">
          {{dIcon "award"}}
          <span>Badge #{{id}}</span>
        </div>
      {{/each}}
    </div>
  </template>
}
