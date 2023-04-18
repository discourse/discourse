import { inject as service } from "@ember/service";
import Component from "@glimmer/component";

export default class BootstrapModeNotice extends Component {
  @service siteSettings;

  get href() {
    const topicId = this.siteSettings.admin_quick_start_topic_id;
    return `/t/-/${topicId}`;
  }
}
