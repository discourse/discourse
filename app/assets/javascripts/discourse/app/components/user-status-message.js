import Component from "@ember/component";
import { computed } from "@ember/object";
import { until } from "discourse/lib/formatter";

export default class UserStatusMessage extends Component {
  tagName = "";
  showTooltip = true;

  @computed("status.ends_at")
  get until() {
    if (!this.status.ends_at) {
      return null;
    }

    return until(
      this.status.ends_at,
      this.currentUser.user_option.timezone,
      this.currentUser.locale
    );
  }
}
