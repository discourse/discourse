import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import getURL from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";

export default class BootstrapModeNotice extends Component {
  @service siteSettings;
  @service userTips;

  @tracked showUserTip = this.userTips.canSeeUserTip("admin_guide");

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
