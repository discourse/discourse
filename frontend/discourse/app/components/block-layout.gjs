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
      <div class="block-layout {{@name}}">
        <div class="block-layout__container">
          <div class="block-layout__layout">
            {{#each this.blocks as |block|}}
              {{#if block.group}}
                <GroupedBlocks @group={{block}} />
              {{else}}
                <WrappedBlock @block={{block}} />
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
      "block-layout__block"
      (concat "block-" @block.component.blockName)
      @block.customClass
    }}
  >
    {{#let (curryComponent @block.component @block.params) as |blockComponent|}}
      <blockComponent />
    {{/let}}
  </div>
</template>;

const GroupedBlocks = <template>
  <div class="block-group__container {{@group.group}}">
    <div class="block-group__layout">
      {{#each @group.blocks as |block|}}
        <WrappedBlock @block={{block}} />
      {{/each}}
    </div>
  </div>
</template>;
