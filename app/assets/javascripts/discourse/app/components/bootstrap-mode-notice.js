import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import DiscourseURL from "discourse/lib/url";
import { hideUserTip } from "discourse/lib/user-tips";
import User from "discourse/models/user";

export default class BootstrapModeNotice extends Component {
  @service siteSettings;

  @tracked isExpanded = false;
  trigger = null;

  @action
  setupTrigger(element) {
    this.isExpanded = User.current().canSeeUserTip("admin_guide");
    this.trigger = element;
  }

  @action
  createPanel(element) {
    User.current().showUserTip({
      id: "admin_guide",
      reference: this.trigger,
      content: element,
    });
  }

  @action
  destroyPanel() {
    hideUserTip("admin_guide");
  }

  @action
  goToAdminGuide() {
    this.isExpanded = false;

    const url = `/t/-/${this.siteSettings.admin_quick_start_topic_id}`;
    DiscourseURL.routeTo(url);
  }

  @action
  dismissUserTip() {
    //
  }
}
