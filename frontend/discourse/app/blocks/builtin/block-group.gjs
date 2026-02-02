import Component from "@glimmer/component";
import { block } from "discourse/blocks/block-outlet";
import { VALID_BLOCK_NAME_PATTERN } from "discourse/lib/blocks";

/**
 * A container block that groups multiple children blocks together.
 * Rendered children are created by the @block decorator and passed via the children getter.
 *
 * The system wrapper provides standard BEM classes:
 * - `block__group` - Standard block class
 * - `{outletName}__group` - Standard outlet class
 *
 * Additional class from classNames decorator option:
 * - `block__group-{name}` - Dynamic class based on name arg
 *
 * System args (curried at creation time, not passed from parent):
 * - `@outletName` - The outlet identifier this group belongs to
 * - `@outletArgs` - Outlet args available for condition evaluation and access
 *
 * @param {string} [name] - Group identifier for BEM class naming (block__group-{name})
 */
@block("group", {
  container: true,
  description: "Groups multiple children blocks together under a named wrapper",
  args: {
    name: { type: "string", pattern: VALID_BLOCK_NAME_PATTERN, required: true },
  },
  classNames: (args) => `block__group-${args.name}`,
})
export default class GroupedBlocks extends Component {
  <template>
    {{#each @children key="key" as |child|}}
      <child.Component />
    {{/each}}
  </template>
}
