import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { gte } from "truth-helpers";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class UserFlagPercentage extends Component {
  // We do a little logic to choose which icon to display and which text
  @cached
  get percentage() {
    const { agreed, disagreed, ignored } = this.args;
    const total = agreed + disagreed + ignored;
    const result = { total };

    if (total <= 0) {
      return result;
    }

    const roundedAgreed = Math.round((agreed / total) * 100);
    const roundedDisagreed = Math.round((disagreed / total) * 100);
    const roundedIgnored = Math.round((ignored / total) * 100);

    const highest = Math.max(agreed, disagreed, ignored);
    if (highest === agreed) {
      result.icon = "thumbs-up";
      result.className = "agreed";
      result.label = `${roundedAgreed}%`;
    } else if (highest === disagreed) {
      result.icon = "thumbs-down";
      result.className = "disagreed";
      result.label = `${roundedDisagreed}%`;
    } else {
      result.icon = "up-right-from-square";
      result.className = "ignored";
      result.label = `${roundedIgnored}%`;
    }

    result.title = i18n("review.user_percentage.summary", {
      agreed: i18n("review.user_percentage.agreed", {
        count: roundedAgreed,
      }),
      disagreed: i18n("review.user_percentage.disagreed", {
        count: roundedDisagreed,
      }),
      ignored: i18n("review.user_percentage.ignored", {
        count: roundedIgnored,
      }),
      count: total,
    });

    return result;
  }

  <template>
    {{#if (gte this.percentage.total 3)}}
      <div title={{this.percentage.title}} class="user-flag-percentage">
        <span
          class="percentage-label {{this.percentage.className}}"
        >{{this.percentage.label}}</span>
        {{icon this.percentage.icon}}
      </div>
    {{/if}}
  </template>
}
