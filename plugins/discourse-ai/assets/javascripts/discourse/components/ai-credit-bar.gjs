import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import { number } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

/**
 * Component to display credit allocation remaining as a horizontal progress bar
 *
 * @component AiCreditBar
 * @param {Object} allocation - LlmCreditAllocation object with monthly_credits, credits_remaining, percentage_remaining, soft_limit_reached, hard_limit_reached, next_reset_at
 * @param {Boolean} showTooltip - Whether to show tooltip on hover (default: true)
 */
export default class AiCreditBar extends Component {
  get barClass() {
    if (this.args.allocation.soft_limit_reached) {
      return "ai-credit-bar--warning";
    }
    return "";
  }

  get fillStyle() {
    return htmlSafe(`width: ${this.args.allocation.percentage_remaining}%`);
  }

  get barText() {
    return i18n("discourse_ai.llms.credit_allocation.credits_remaining", {
      remaining: number(this.args.allocation.credits_remaining),
      total: number(this.args.allocation.monthly_credits),
      percentage: this.args.allocation.percentage_remaining,
    });
  }

  get tooltipText() {
    const resetDate = new Date(this.args.allocation.next_reset_at);
    const options = {
      month: "long",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    };
    const formattedDate = resetDate.toLocaleString(undefined, options);

    return i18n("discourse_ai.llms.credit_allocation.next_reset", {
      time: formattedDate,
    });
  }

  get shouldShowTooltip() {
    return this.args.showTooltip !== false;
  }

  <template>
    {{#if this.shouldShowTooltip}}
      <DTooltip @content={{this.tooltipText}}>
        <:trigger>
          <div class={{concatClass "ai-credit-bar" this.barClass}}>
            <div class="ai-credit-bar__progress">
              <div class="ai-credit-bar__fill" style={{this.fillStyle}}></div>
            </div>
            <div class="ai-credit-bar__text">
              {{this.barText}}
            </div>
          </div>
        </:trigger>
      </DTooltip>
    {{else}}
      <div class={{concatClass "ai-credit-bar" this.barClass}}>
        <div class="ai-credit-bar__progress">
          <div class="ai-credit-bar__fill" style={{this.fillStyle}}></div>
        </div>
        <div class="ai-credit-bar__text">
          {{this.barText}}
        </div>
      </div>
    {{/if}}
  </template>
}
