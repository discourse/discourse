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
      type: "string",
      default: "",
      ui: {
        label: "Badge IDs",
        helpText: "Comma-separated badge IDs (e.g. 1, 3, 7).",
      },
    },
  },
})
export default class VEBadgesGrid extends Component {
  get tiles() {
    const raw = this.args.badgeIds;
    if (typeof raw !== "string" || !raw.trim()) {
      return [1, 2, 3, 4];
    }
    const ids = raw
      .split(/[,|]/)
      .map((s) => parseInt(s.trim(), 10))
      .filter((n) => Number.isInteger(n) && n > 0);
    return ids.length ? ids : [1, 2, 3, 4];
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
