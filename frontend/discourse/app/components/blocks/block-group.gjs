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
        (concat @blockOutlet "__group ")
        (concat "block__group-" @group.group)
        @block.classNames
      }}
    >
      {{#each this.children as |item|}}
        <item.Component @block={{item}} @outletName={{@outletName}} />
      {{/each}}
    </div>
  </template>
}
