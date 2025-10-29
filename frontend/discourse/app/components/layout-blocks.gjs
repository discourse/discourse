import Component from "@glimmer/component";
import { blockConfigs } from "discourse/lib/plugin-api";

export default class LayoutBlocks extends Component {
  get blocks() {
    return blockConfigs.get(this.args.name);
  }

  get shouldShow() {
    return blockConfigs.has(this.args.name);
  }

  <template>
    {{#if this.shouldShow}}
      <div class="{{@className}} {{@className}}__container">
        <div class="{{@className}}__blocks">
          {{#each this.blocks as |block|}}
            <div class="{{block.component.blockName}} {{block.name}}">
              <block.component @params={{block.params}} />
            </div>
          {{/each}}
        </div>
      </div>
    {{/if}}
  </template>
}
