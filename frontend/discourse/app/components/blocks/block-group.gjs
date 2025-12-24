import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { block } from "discourse/components/block-outlet";
import concatClass from "discourse/helpers/concat-class";

@block
export class GroupedBlocks extends Component {
  <template>
    <div class={{concatClass (concat @blockOutlet "__group ") @group.group}}>
      {{#each @group.blocks as |item|}}
        <WrappedBlock @block={{item}} @blockOutlet={{@blockOutlet}} />
      {{/each}}
    </div>
  </template>
}
