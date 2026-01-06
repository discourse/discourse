import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import icon from "discourse/helpers/d-icon";
import ArgsTable from "./args-table";
import ConditionsTree from "./conditions-tree";

/**
 * Visual overlay component for rendered blocks.
 * Wraps a block with debug information including name badge and tooltip.
 *
 * @component BlockInfo
 * @param {string} blockName - The name of the block
 * @param {string} debugLocation - The hierarchy path where the block is rendered
 * @param {Object} blockArgs - Arguments passed to the block
 * @param {Object} conditions - Conditions that were evaluated
 * @param {Object} [outletArgs] - Outlet arguments available to the block
 * @param {Component} WrappedComponent - The actual block component to render
 */
export default class BlockInfo extends Component {
  /**
   * Checks whether this block has any conditions configured.
   * Used to conditionally render the conditions section in the tooltip.
   *
   * @returns {boolean} True if the block has conditions defined.
   */
  get hasConditions() {
    return this.args.conditions != null;
  }

  /**
   * Checks whether this block has any arguments passed to it.
   * Used to conditionally render the arguments section in the tooltip.
   *
   * @returns {boolean} True if the block has at least one argument.
   */
  get hasArgs() {
    return (
      this.args.blockArgs != null && Object.keys(this.args.blockArgs).length > 0
    );
  }

  /**
   * Checks whether this block has outlet args available.
   * Used to conditionally render the outlet args section in the tooltip.
   *
   * @returns {boolean} True if outlet args are available.
   */
  get hasOutletArgs() {
    return (
      this.args.outletArgs != null &&
      Object.keys(this.args.outletArgs).length > 0
    );
  }

  <template>
    <div class="block-debug-info --rendered" data-block-name={{@blockName}}>
      <DTooltip
        @identifier="block-debug-info"
        @interactive={{true}}
        @placement="bottom-start"
        @maxWidth={{500}}
        @triggers={{hash
          mobile=(array "click")
          desktop=(array "hover" "click")
        }}
        @untriggers={{hash mobile=(array "click") desktop=(array "mouseleave")}}
      >
        <:trigger>
          <span class="block-debug-badge">
            {{icon "cube"}}
            <span class="block-debug-badge__name">{{@blockName}}</span>
          </span>
        </:trigger>
        <:content>
          <div class="block-debug-tooltip">
            <div class="block-debug-tooltip__header">
              {{icon "cube"}}
              <span class="block-debug-tooltip__title">{{@blockName}}</span>
              <span class="block-debug-tooltip__outlet">in
                {{@debugLocation}}</span>
            </div>

            {{#if this.hasConditions}}
              <div class="block-debug-tooltip__section">
                <div class="block-debug-tooltip__section-title">Conditions
                  <span class="--passed">(passed)</span></div>
                <ConditionsTree @conditions={{@conditions}} @passed={{true}} />
              </div>
            {{/if}}

            {{#if this.hasArgs}}
              <div class="block-debug-tooltip__section">
                <div class="block-debug-tooltip__section-title">Arguments</div>
                <ArgsTable @args={{@blockArgs}} />
              </div>
            {{/if}}

            {{#if this.hasOutletArgs}}
              <div class="block-debug-tooltip__section">
                <div class="block-debug-tooltip__section-title">Outlet Args</div>
                <ArgsTable @args={{@outletArgs}} />
              </div>
            {{/if}}

            {{#unless this.hasConditions}}
              {{#unless this.hasArgs}}
                {{#unless this.hasOutletArgs}}
                  <div class="block-debug-tooltip__empty">
                    No conditions or arguments
                  </div>
                {{/unless}}
              {{/unless}}
            {{/unless}}
          </div>
        </:content>
      </DTooltip>
      <@WrappedComponent />
    </div>
  </template>
}
