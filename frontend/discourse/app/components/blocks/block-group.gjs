import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { block } from "discourse/components/block-outlet";
import concatClass from "discourse/helpers/concat-class";

/**
 * @component group
 * @description A block that groups multiple children blocks together.
 * @param {string} blockOutlet - The name of the outlet this group belongs to
 * @param {Object} group - The group configuration object
 */
@block("group", { container: true })
export default class GroupedBlocks extends Component {
  <template>
    <div
      class={{concatClass
        (concat @outletName "__group")
        (concat "block__group-" @group)
        @classNames
      }}
    >
      {{#each this.children as |child|}}
        <child.Component @block={{child}} @outletName={{@outletName}} />
      {{/each}}
    </div>
  </template>
}
