import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { service } from "@ember/service";
import curryComponent from "ember-curry-component";
import concatClass from "discourse/helpers/concat-class";
import { blockConfigs } from "discourse/lib/plugin-api";
import { or } from "discourse/truth-helpers";

export default class BlockFrame extends Component {
  @service discovery;

  get blocks() {
    const blocks = blockConfigs.get(this.args.name);

    if (!blocks) {
      return [];
    }

    const resolvedBlocks = [];

    for (const block of blocks) {
      if (block.type === "conditional") {
        const shouldRender =
          (block.routes.includes("discovery") &&
            this.discovery.onDiscoveryRoute &&
            !this.discovery.custom) ||
          (block.routes.includes("homepage") && this.discovery.custom) ||
          (block.routes.includes("category") && this.discovery.category) ||
          (block.routes.includes("top-menu") &&
            this.discovery.onDiscoveryRoute &&
            !this.discovery.category &&
            !this.discovery.tag &&
            !this.discovery.custom);

        if (shouldRender) {
          resolvedBlocks.push(...block.blocks);
        }
      } else {
        resolvedBlocks.push(block);
      }
    }

    return resolvedBlocks;
  }

  get shouldShow() {
    return this.blocks.length > 0;
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
    {{#let
      (curryComponent @block.component (or @block.params (hash)))
      as |BlockComponent|
    }}
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
