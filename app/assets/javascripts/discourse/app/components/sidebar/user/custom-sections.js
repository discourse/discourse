import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse-common/utils/decorators";
import Section from "discourse/lib/sidebar/section";
import CommunitySection from "discourse/lib/sidebar/community-section";

export default class SidebarUserCustomSections extends Component {
  @service currentUser;
  @service router;
  @service messageBus;
  @service appEvents;
  @service topicTrackingState;
  @service siteSettings;

  constructor() {
    super(...arguments);
    this.messageBus.subscribe("/refresh-sidebar-sections", this._refresh);
    this.cacheSections;
  }

  willDestroy() {
    this.messageBus.unsubscribe("/refresh-sidebar-sections");
    return this.cacheSections.forEach((section) => {
      section.teardown?.();
    });
  }

  get sections() {
    this.cacheSections = this.currentUser.sidebarSections.map((section) => {
      switch (section.section_type) {
        case "community":
          const systemSection = new CommunitySection({
            section,
            currentUser: this.currentUser,
            router: this.router,
            appEvents: this.appEvents,
            topicTrackingState: this.topicTrackingState,
            siteSettings: this.siteSettings,
          });
          return systemSection;
          break;
        default:
          return new Section({
            section,
            currentUser: this.currentUser,
            router: this.router,
          });
      }
    });
    return this.cacheSections;
  }

  @bind
  _refresh() {
    return ajax("/sidebar_sections.json", {}).then((json) => {
      this.currentUser.set("sidebar_sections", json.sidebar_sections);
    });
  }
}
