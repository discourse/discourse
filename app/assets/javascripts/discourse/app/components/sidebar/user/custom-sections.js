import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse-common/utils/decorators";
import { cached } from "@glimmer/tracking";
import Section from "discourse/lib/sidebar/section";
import CommunitySection from "discourse/lib/sidebar/community-section";

export default class SidebarUserCustomSections extends Component {
  @service currentUser;
  @service router;
  @service messageBus;
  @service appEvents;
  @service topicTrackingState;
  @service site;
  @service siteSettings;

  constructor() {
    super(...arguments);
    this.messageBus.subscribe("/refresh-sidebar-sections", this._refresh);
  }

  willDestroy() {
    this.messageBus.unsubscribe("/refresh-sidebar-sections");
    return this.sections.forEach((section) => {
      section.teardown?.();
    });
  }

  @cached
  get sections() {
    return this.currentUser.sidebarSections.map((section) => {
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
  }

  get isDesktopDropdownMode() {
    const headerDropdownMode =
      this.siteSettings.navigation_menu === "header dropdown";

    return !this.site.mobileView && headerDropdownMode;
  }

  @bind
  _refresh() {
    return ajax("/sidebar_sections.json", {}).then((json) => {
      this.currentUser.set("sidebar_sections", json.sidebar_sections);
    });
  }
}
