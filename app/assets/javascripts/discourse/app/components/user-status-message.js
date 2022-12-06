import Component from "@ember/component";
import { computed } from "@ember/object";
import { until } from "discourse/lib/formatter";
import { AnonymousUser } from "discourse/lib/anonymous-user";

export default class UserStatusMessage extends Component {
  tagName = "";
  showTooltip = true;

  @computed("status.ends_at")
  get until() {
    if (!this.status.ends_at) {
      return null;
    }

    const user = this.currentUser || new AnonymousUser();
    return until(this.status.ends_at, user.timezone, user.locale);
  }
}
