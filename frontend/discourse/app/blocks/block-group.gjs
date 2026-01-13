import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { block } from "discourse/components/block-outlet";
import concatClass from "discourse/helpers/concat-class";
import dasherize from "discourse/helpers/dasherize";
import { VALID_BLOCK_NAME_PATTERN } from "discourse/lib/blocks/patterns";

/**
 * A container block that groups multiple children blocks together.
 * Rendered children are created by the @block decorator and passed via the children getter.
 *
 * @param {string} @outletName - The outlet identifier this group belongs to (passed from parent)
 * @param {Object} [@outletArgs] - Outlet args to forward to children (for condition evaluation and access)
 * @param {string} [@classNames] - Additional CSS classes for the group wrapper
 * @param {string} [@name] - Group identifier for BEM class naming (block__group-{name})
 */
@block("group", {
  container: true,
  args: {
    name: { type: "string", pattern: VALID_BLOCK_NAME_PATTERN, required: true },
  },
})
export default class GroupedBlocks extends Component {
  <template>
    <div
      class={{concatClass
        (concat "block__group-" (dasherize @name))
        (concat (dasherize @outletName) "__group")
        @classNames
      }}
    >
      {{#each this.children key="key" as |child|}}
        <child.Component
          @outletName={{@outletName}}
          @outletArgs={{@outletArgs}}
        />
      {{/each}}
    </div>
  </template>
}
