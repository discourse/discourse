import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import icon from "discourse/helpers/d-icon";

/**
 * Debug overlay for BlockOutlet components.
 * Shows outlet name badge with a tooltip containing outlet info and GitHub search link.
 *
 * @param {string} outletName - The name of the block outlet.
 * @param {number} blockCount - Number of blocks registered.
 */
export default class OutletInfo extends Component {
  get blockLabel() {
    const count = this.args.blockCount;
    return count === 1 ? "1 block" : `${count} blocks`;
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
        <div class="block-outlet-info__wrapper">
          <div class="block-outlet-info__heading">
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
          <div class="block-outlet-info__content">
            {{#if @blockCount}}
              <div class="block-outlet-info__stat">
                {{icon "cube"}}
                <span>{{this.blockLabel}} registered</span>
              </div>
            {{else}}
              <div class="block-outlet-info__empty">
                No blocks registered for this outlet
              </div>
            {{/if}}
          </div>
        </div>
      </:content>
    </DTooltip>
  </template>
}
