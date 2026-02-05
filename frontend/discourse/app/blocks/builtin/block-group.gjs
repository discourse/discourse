// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";

/**
 * A container block that groups multiple children blocks together.
 * Rendered children are pre-processed by the block outlet system and passed via the @children arg.
 *
 * The system wrapper provides standard BEM classes:
 * - `{outletName}__block-container` - Standard container class
 * - `{outletName}__block-container--{id}` - BEM modifier when entry has an `id`
 *
 * System args (curried at creation time, not passed from parent):
 * - `@outletName` - The outlet identifier this group belongs to
 * - `@outletArgs` - Outlet args available for condition evaluation and access
 */
@block("group", {
  container: true,
  description: "Groups multiple children blocks together",
})
export default class GroupedBlocks extends Component {
  <template>
    {{#each @children key="key" as |child|}}
      <child.Component />
    {{/each}}
  </template>
}
