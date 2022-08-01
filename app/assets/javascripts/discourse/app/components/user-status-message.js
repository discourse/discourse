import Component from "@ember/component";
import { computed } from "@ember/object";
import I18n from "I18n";

export default class extends Component {
  tagName = "";

  @computed("status.ends_at")
  get until() {
    if (!this.status.ends_at) {
      return null;
    }

    const timezone = this.currentUser.timezone;
    const endsAt = moment.tz(this.status.ends_at, timezone);
    const now = moment.tz(timezone);
    const until = I18n.t("user_status.until");

    if (now.isSame(endsAt, "day")) {
      const localeData = moment.localeData(this.currentUser.locale);
      return `${until} ${endsAt.format(localeData.longDateFormat("LT"))}`;
    } else {
      return `${until} ${endsAt.format("MMM D")}`;
    }
  }
}
