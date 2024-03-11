import Component from "@glimmer/component";
import { service } from "@ember/service";
import { until } from "discourse/lib/formatter";

export default class UserStatusMessage extends Component {
  @service currentUser;

  get until() {
    if (!this.args.status.ends_at) {
      return;
    }

    const timezone = this.currentUser
      ? this.currentUser.user_option?.timezone
      : moment.tz.guess();

    return until(this.args.status.ends_at, timezone, this.currentUser?.locale);
  }
}
