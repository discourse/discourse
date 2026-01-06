import { array, hash } from "@ember/helper";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import icon from "discourse/helpers/d-icon";
import ConditionsTree from "./conditions-tree";

/**
 * Ghost placeholder for blocks that are hidden.
 * Shows a dashed outline indicating where the block would render.
 *
 * Blocks can be hidden for two reasons:
 * - **Optional missing**: Block reference uses `?` suffix but isn't registered
 * - **Conditions failed**: Block is registered but conditions evaluated to false
 *
 * @component GhostBlock
 * @param {string} blockName - The name of the hidden block.
 * @param {string} debugLocation - The hierarchy path where the block would render.
 * @param {Object} [conditions] - Conditions that failed evaluation (not present for optional missing).
 * @param {boolean} [optionalMissing] - True if block is optional and not registered.
 */
const GhostBlock = <template>
  <div class="block-debug-ghost" data-block-name={{@blockName}}>
    <DTooltip
      @identifier="block-debug-ghost"
      @interactive={{true}}
      @placement="bottom-start"
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
            <span class="block-debug-tooltip__outlet">in
              {{@debugLocation}}</span>
            <span class="block-debug-tooltip__status">HIDDEN</span>
          </div>

          {{#if @optionalMissing}}
            <div class="block-debug-tooltip__section">
              <div class="block-debug-tooltip__section-title">
                Status
                <span class="--failed">(not registered)</span>
              </div>
            </div>

            <div class="block-debug-tooltip__hint">
              This optional block is not rendered because it's not registered.
            </div>
          {{else}}
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
          {{/if}}
        </div>
      </:content>
    </DTooltip>
  </div>
</template>;

export default GhostBlock;
