import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class MergeUsersProgress extends Component {
  @service messageBus;

  @tracked message = i18n("admin.user.merging_user");

  constructor() {
    super(...arguments);
    this.messageBus.subscribe("/merge_user", this.onMessage);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe("/merge_user", this.onMessage);
  }

  @bind
  onMessage(data) {
    if (data.merged) {
      if (/^\/admin\/users\/list\//.test(location.href)) {
        DiscourseURL.redirectTo(location.href);
      } else {
        DiscourseURL.redirectTo(
          `/admin/users/${data.user.id}/${data.user.username}`
        );
      }
    } else if (data.message) {
      this.message = data.message;
    } else if (data.failed) {
      this.message = i18n("admin.user.merge_failed");
    }
  }
}
