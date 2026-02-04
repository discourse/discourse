// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import { VALID_BLOCK_NAME_PATTERN } from "discourse/lib/blocks";

/**
 * A container block that groups multiple children blocks together.
 * Rendered children are pre-processed by the block outlet system and passed via the @children arg.
 *
 * The system wrapper provides standard BEM classes:
 * - `block-group` - Standard block class
 * - `{outletName}__group` - Standard outlet class
 *
 * Additional class from classNames decorator option:
 * - `block-group-{name}` - Dynamic class based on name arg
 *
 * System args (curried at creation time, not passed from parent):
 * - `@outletName` - The outlet identifier this group belongs to
 * - `@outletArgs` - Outlet args available for condition evaluation and access
 *
 * @param {string} name - Group identifier for BEM class naming (block-group-{name}). Required.
 */
@block("group", {
  container: true,
  description: "Groups multiple children blocks together under a named wrapper",
  args: {
    name: { type: "string", pattern: VALID_BLOCK_NAME_PATTERN, required: true },
  },
  classNames: (args) => `block-group-${args.name}`,
})
export default class GroupedBlocks extends Component {
  <template>
    {{#each @children key="key" as |child|}}
      <child.Component />
    {{/each}}
  </template>
}
