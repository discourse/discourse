// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@block("ve:recent-topics", {
  displayName: "Recent Topics",
  icon: "clock",
  category: "Data",
  description: "Placeholder list of recent topics (static for now).",
  args: {
    limit: {
      type: "number",
      default: 5,
      integer: true,
      min: 1,
      max: 20,
      ui: { label: "Limit" },
    },
    category: {
      type: "string",
      default: "",
      ui: { control: "category-select", label: "Category" },
    },
  },
  previewArgs: { limit: 5 },
})
export default class VERecentTopics extends Component {
  get placeholders() {
    const limit = Math.max(1, Math.min(20, this.args.limit ?? 5));
    return Array.from({ length: limit }, (_, i) => i);
  }

  <template>
    <ul class="ve-recent-topics">
      {{#each this.placeholders as |i|}}
        <li class="ve-recent-topics__item">
          {{dIcon "comments"}}
          <span>Topic placeholder #{{i}}</span>
        </li>
      {{/each}}
    </ul>
  </template>
}
