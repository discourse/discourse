import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import DiscourseURL from "discourse/lib/url";
import User from "discourse/models/user";

export default class BootstrapModeNotice extends Component {
  @service siteSettings;

  @tracked showUserTip = false;

  @action
  setupUserTip() {
    this.showUserTip = User.current().canSeeUserTip("admin_guide");
  }

  @action
  routeToAdminGuide() {
    this.showUserTip = false;
    DiscourseURL.routeTo(
      `/t/-/${this.siteSettings.admin_quick_start_topic_id}`
    );
  }
}
