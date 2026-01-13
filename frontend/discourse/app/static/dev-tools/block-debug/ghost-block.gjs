import { array, hash } from "@ember/helper";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import icon from "discourse/helpers/d-icon";
import ArgsTable from "../shared/args-table";
import ConditionsTree from "./conditions-tree";

/**
 * Returns the appropriate hint message based on why the block is hidden.
 *
 * @param {boolean} optionalMissing - True if block is optional and not registered.
 * @param {string} failureReason - Why the block is hidden ("condition-failed" or "no-visible-children").
 * @returns {string} The hint message to display.
 */
function getHintMessage(optionalMissing, failureReason) {
  if (optionalMissing) {
    return "This optional block is not rendered because it's not registered.";
  }
  if (failureReason === "no-visible-children") {
    return "This container block is not rendered because none of its children are visible.";
  }
  return "This block is not rendered because its conditions failed.";
}

/**
 * Ghost placeholder for blocks that are hidden.
 * Shows a dashed outline indicating where the block would render.
 *
 * Blocks can be hidden for several reasons:
 * - **Optional missing**: Block reference uses `?` suffix but isn't registered
 * - **Conditions failed**: Block is registered but conditions evaluated to false
 * - **No visible children**: Container block has no children that pass their conditions
 *
 * For container blocks hidden due to no visible children, nested ghost children
 * are rendered inside to show the full block tree structure.
 *
 * @component GhostBlock
 * @param {string} blockName - The name of the hidden block.
 * @param {string} debugLocation - The hierarchy path where the block would render.
 * @param {Object} [blockArgs] - Arguments that would have been passed to the block.
 * @param {Object} [containerArgs] - Container arguments from parent container's childArgs.
 * @param {Object} [conditions] - Conditions that failed evaluation (not present for optional missing).
 * @param {boolean} [optionalMissing] - True if block is optional and not registered.
 * @param {string} [failureReason] - Why the block is hidden ("condition-failed" or "no-visible-children").
 * @param {Array<{Component: CurriedComponent}>} [children] - Nested ghost children for container blocks.
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
          {{else if (isNoVisibleChildren @failureReason)}}
            <div class="block-debug-tooltip__section">
              <div class="block-debug-tooltip__section-title">
                Status
                <span class="--failed">(no visible children)</span>
              </div>
            </div>
          {{else}}
            <div class="block-debug-tooltip__section">
              <div class="block-debug-tooltip__section-title">
                Conditions
                <span class="--failed">(failed)</span>
              </div>
              <ConditionsTree @conditions={{@conditions}} @passed={{false}} />
            </div>
          {{/if}}

          {{#if (hasArgs @blockArgs)}}
            <div class="block-debug-tooltip__section">
              <div class="block-debug-tooltip__section-title">Arguments</div>
              <ArgsTable @args={{@blockArgs}} />
            </div>
          {{/if}}

          {{#if (hasArgs @containerArgs)}}
            <div class="block-debug-tooltip__section">
              <div class="block-debug-tooltip__section-title">Container Args</div>
              <ArgsTable @args={{@containerArgs}} />
            </div>
          {{/if}}

          <div class="block-debug-tooltip__hint">
            {{getHintMessage @optionalMissing @failureReason}}
          </div>
        </div>
      </:content>
    </DTooltip>

    {{! Render nested ghost children for container blocks with no visible children }}
    {{#if @children.length}}
      <div class="block-debug-ghost__children">
        {{#each @children as |child|}}
          <child.Component />
        {{/each}}
      </div>
    {{/if}}
  </div>
</template>;

/**
 * Helper to check if failure reason is "no-visible-children".
 *
 * @param {string} failureReason - The failure reason.
 * @returns {boolean} True if the reason is "no-visible-children".
 */
function isNoVisibleChildren(failureReason) {
  return failureReason === "no-visible-children";
}

/**
 * Helper to check if an args object has any entries.
 *
 * @param {Object} args - The arguments object to check.
 * @returns {boolean} True if args is non-null and has at least one key.
 */
function hasArgs(args) {
  return args != null && Object.keys(args).length > 0;
}

export default GhostBlock;
