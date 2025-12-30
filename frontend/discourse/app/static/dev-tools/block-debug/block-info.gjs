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
 * @param {string} outletName - The outlet where the block is rendered
 * @param {Object} blockArgs - Arguments passed to the block
 * @param {Object} conditions - Conditions that were evaluated
 * @param {Component} WrappedComponent - The actual block component to render
 */
export default class BlockInfo extends Component {
  get hasConditions() {
    return this.args.conditions != null;
  }

  get hasArgs() {
    return (
      this.args.blockArgs != null && Object.keys(this.args.blockArgs).length > 0
    );
  }

  <template>
    <div class="block-debug-info --rendered" data-block-name={{@blockName}}>
      <DTooltip
        @identifier="block-debug-info"
        @interactive={{true}}
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
                {{@outletName}}</span>
            </div>

            {{#if this.hasConditions}}
              <div class="block-debug-tooltip__section">
                <div class="block-debug-tooltip__section-title">Conditions
                  (passed)</div>
                <ConditionsTree @conditions={{@conditions}} @passed={{true}} />
              </div>
            {{/if}}

            {{#if this.hasArgs}}
              <div class="block-debug-tooltip__section">
                <div class="block-debug-tooltip__section-title">Arguments</div>
                <ArgsTable @args={{@blockArgs}} />
              </div>
            {{/if}}

            {{#unless this.hasConditions}}
              {{#unless this.hasArgs}}
                <div class="block-debug-tooltip__empty">
                  No conditions or arguments
                </div>
              {{/unless}}
            {{/unless}}
          </div>
        </:content>
      </DTooltip>
      <@WrappedComponent />
    </div>
  </template>
}
