import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class SidebarCustomSection extends Component {
  @service currentUser;
  @service router;
  @service messageBus;
  @service appEvents;
  @service topicTrackingState;
  @service site;
  @service siteSettings;

  anonymous = false;

  get sections() {
    if (this.anonymous) {
      return this.site.anonymous_sidebar_sections;
    } else {
      return this.currentUser.sidebarSections;
    }
  }
}
