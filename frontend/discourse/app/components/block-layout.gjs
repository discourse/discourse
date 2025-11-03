import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import curryComponent from "ember-curry-component";
import concatClass from "discourse/helpers/concat-class";
import { blockConfigs } from "discourse/lib/plugin-api";

export default class BlockLayout extends Component {
  get blocks() {
    return blockConfigs.get(this.args.name);
  }

  get shouldShow() {
    return blockConfigs.has(this.args.name);
  }

  <template>
    {{#if this.shouldShow}}
      <div class={{@name}}>
        <div class={{concat @name "__container"}}>
          <div class={{concat @name "__layout"}}>
            {{#each this.blocks as |block|}}
              {{#if block.group}}
                <GroupedBlocks @group={{block}} @blockLayoutName={{@name}} />
              {{else}}
                <WrappedBlock @block={{block}} @blockLayoutName={{@name}} />
              {{/if}}
            {{/each}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}

const WrappedBlock = <template>
  <div
    class={{concatClass
      (concat @blockLayoutName "__block ")
      (concat "block-" @block.component.blockName)
      @block.customClass
    }}
  >
    {{#let (curryComponent @block.component @block.params) as |BlockComponent|}}
      <BlockComponent />
    {{/let}}
  </div>
</template>;

const GroupedBlocks = <template>
  <div class={{concatClass (concat @blockLayoutName "__group ") @group.group}}>
    {{#each @group.blocks as |block|}}
      <WrappedBlock @block={{block}} @blockLayoutName={{@blockLayoutName}} />
    {{/each}}

  </div>
</template>;
