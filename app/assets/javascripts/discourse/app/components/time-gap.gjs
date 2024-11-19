import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class TimeGap extends Component {
  get description() {
    const daysSince = this.args.daysSince;

    if (daysSince < 30) {
      return i18n("dates.later.x_days", { count: daysSince });
    } else if (daysSince < 365) {
      const gapMonths = Math.round(daysSince / 30);
      return i18n("dates.later.x_months", { count: gapMonths });
    } else {
      const gapYears = Math.round(daysSince / 365);
      return i18n("dates.later.x_years", { count: gapYears });
    }
  }

  <template>
    <div class="topic-avatar"></div>
    <div class="small-action-desc timegap">
      {{this.description}}
    </div>
  </template>
}
