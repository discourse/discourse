import getURL from "discourse-common/lib/get-url";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";
import DiscourseURL from "discourse/lib/url";

export default class BootstrapModeNotice extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked showUserTip = false;

  @action
  setupUserTip() {
    this.showUserTip = this.currentUser?.canSeeUserTip("admin_guide");
  }

  @action
  routeToAdminGuide() {
    this.showUserTip = false;
    DiscourseURL.routeTo(
      `/t/-/${this.siteSettings.admin_quick_start_topic_id}`
    );
  }

  get adminGuideUrl() {
    return getURL(`/t/-/${this.siteSettings.admin_quick_start_topic_id}`);
  }

  get userTipContent() {
    return I18n.t("user_tips.admin_guide.content", {
      admin_guide_url: this.adminGuideUrl,
    });
  }
}
