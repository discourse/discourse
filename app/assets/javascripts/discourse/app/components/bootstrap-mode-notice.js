import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";

export default class BootstrapModeNotice extends Component {
  @service siteSettings;

  @action
  routeToAdminGuide() {
    DiscourseURL.routeTo(
      `/t/-/${this.siteSettings.admin_quick_start_topic_id}`
    );
  }
}
