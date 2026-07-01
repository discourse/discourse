// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import ListThumbnail from "discourse/components/svg/blocks/list";
import { i18n } from "discourse-i18n";

/**
 * An ordered or unordered list. The entries are a single `items` arg (an array
 * of `{ content }` objects), so the whole list is edited as one repeatable
 * field. Nested sub-lists are intentionally out of scope for now — compose
 * separate `list` blocks for nesting.
 */
@block("list", {
  thumbnail: ListThumbnail,
  displayName: "List",
  icon: "list",
  category: "Content",
  description: "An ordered or unordered list of items.",
  args: {
    ordered: {
      type: "boolean",
      default: false,
      ui: { control: "toggle", label: i18n("blocks.builtin.list.ordered") },
    },
    items: {
      type: "array",
      itemType: "object",
      default: [],
      itemSchema: {
        content: {
          type: "string",
          required: true,
          ui: { label: i18n("blocks.builtin.list.item_content") },
        },
      },
      ui: {
        control: "repeatable",
        label: i18n("blocks.builtin.list.items"),
      },
    },
  },
})
export default class List extends Component {
  get items() {
    return this.args.items ?? [];
  }

  <template>
    {{#if @ordered}}
      <ol class="d-block-list d-block-list--ordered">
        {{#each this.items key="@index" as |item|}}
          <li class="d-block-list__item">{{item.content}}</li>
        {{/each}}
      </ol>
    {{else}}
      <ul class="d-block-list d-block-list--unordered">
        {{#each this.items key="@index" as |item|}}
          <li class="d-block-list__item">{{item.content}}</li>
        {{/each}}
      </ul>
    {{/if}}
  </template>
}
