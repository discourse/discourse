import { array, hash } from "@ember/helper";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import icon from "discourse/helpers/d-icon";
import ConditionsTree from "./conditions-tree";

/**
 * Ghost placeholder for blocks that fail their conditions.
 * Shows a dashed outline indicating where the block would render.
 *
 * @component GhostBlock
 * @param {string} blockName - The name of the hidden block
 * @param {string} outletName - The outlet where the block would render
 * @param {Object} conditions - Conditions that failed evaluation
 */
const GhostBlock = <template>
  <div class="block-debug-ghost" data-block-name={{@blockName}}>
    <DTooltip
      @identifier="block-debug-ghost"
      @interactive={{true}}
      @maxWidth={{500}}
      @triggers={{hash mobile=(array "click") desktop=(array "hover" "click")}}
      @untriggers={{hash mobile=(array "click") desktop=(array "mouseleave")}}
    >
      <:trigger>
        <span class="block-debug-ghost__badge">
          {{icon "cube"}}
          <span class="block-debug-ghost__name">{{@blockName}}</span>
          <span class="block-debug-ghost__status">(hidden)</span>
        </span>
      </:trigger>
      <:content>
        <div class="block-debug-tooltip --ghost">
          <div class="block-debug-tooltip__header --failed">
            {{icon "cube"}}
            <span class="block-debug-tooltip__title">{{@blockName}}</span>
            <span class="block-debug-tooltip__status">HIDDEN</span>
          </div>

          <div class="block-debug-tooltip__section">
            <div class="block-debug-tooltip__section-title">
              Conditions
              <span class="--failed">(failed)</span>
            </div>
            <ConditionsTree @conditions={{@conditions}} @passed={{false}} />
          </div>

          <div class="block-debug-tooltip__hint">
            This block is not rendered because its conditions failed.
          </div>
        </div>
      </:content>
    </DTooltip>
  </div>
</template>;

export default GhostBlock;
