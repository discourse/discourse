import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import icon from "discourse/helpers/d-icon";
import { DEPRECATED_ARGS_KEY } from "discourse/lib/outlet-args";
import ArgsTable from "../shared/args-table";

/**
 * Debug overlay for BlockOutlet components.
 * Shows outlet name badge with a tooltip containing outlet info and GitHub search link.
 *
 * @param {string} outletName - The name of the block outlet.
 * @param {number} blockCount - Number of blocks registered.
 * @param {Object} [outletArgs] - Arguments passed to the outlet. May contain a non-enumerable
 *   `__deprecatedArgs__` property with the raw deprecated args for display in the debug tooltip.
 */
export default class OutletInfo extends Component {
  get blockLabel() {
    const count = this.args.blockCount;
    return count === 1 ? "1 block" : `${count} blocks`;
  }

  /**
   * Checks whether this outlet has any args passed to it.
   *
   * @returns {boolean} True if outlet has at least one arg.
   */
  get hasOutletArgs() {
    const outletArgs = this.args.outletArgs;
    const deprecatedArgs = outletArgs?.[DEPRECATED_ARGS_KEY];

    return (
      (outletArgs != null && Object.keys(outletArgs).length > 0) ||
      (deprecatedArgs != null && Object.keys(deprecatedArgs).length > 0)
    );
  }

  <template>
    <DTooltip
      @identifier="block-outlet-info"
      @interactive={{true}}
      @placement="bottom-start"
      @maxWidth={{400}}
      @triggers={{hash mobile=(array "click") desktop=(array "hover")}}
      @untriggers={{hash mobile=(array "click") desktop=(array "click")}}
    >
      <:trigger>
        <span class="block-outlet-debug__badge">
          {{icon "cubes"}}
          {{@outletName}}
        </span>
      </:trigger>
      <:content>
        <div class="outlet-info__wrapper">
          <div class="outlet-info__heading --block-outlet">
            <span class="title">
              {{icon "cubes"}}
              {{@outletName}}
            </span>
            <a
              class="github-link"
              href="https://github.com/search?q=repo%3Adiscourse%2Fdiscourse%20BlockOutlet%20@name=%22{{@outletName}}%22&type=code"
              target="_blank"
              rel="noopener noreferrer"
              title="Find on GitHub"
            >{{icon "fab-github"}}</a>
          </div>
          <div class="outlet-info__content">
            {{#if @blockCount}}
              <div class="outlet-info__section">
                <div class="outlet-info__section-title">Blocks Registered</div>
                <div class="outlet-info__stat">
                  {{icon "cube"}}
                  <span>{{this.blockLabel}}</span>
                </div>
              </div>
            {{else}}
              <div class="outlet-info__empty">
                No blocks registered for this outlet
              </div>
            {{/if}}

            {{#if this.hasOutletArgs}}
              <div class="outlet-info__section">
                <div class="outlet-info__section-title">Outlet Args</div>
                <ArgsTable @args={{@outletArgs}} @prefix="block outlet" />
              </div>
            {{/if}}
          </div>
        </div>
      </:content>
    </DTooltip>
  </template>
}
