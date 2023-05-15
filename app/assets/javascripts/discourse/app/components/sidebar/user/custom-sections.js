import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse-common/utils/decorators";
import Section from "discourse/lib/sidebar/section";
import CommunitySection from "discourse/lib/sidebar/community-section";
import { tracked } from "@glimmer/tracking";

export const REFRESH_CUSTOM_SIDEBAR_SECTIONS_APP_EVENT_NAME =
  "sidebar:refresh-custom-sections";

export default class SidebarUserCustomSections extends Component {
  @service currentUser;
  @service router;
  @service messageBus;
  @service appEvents;
  @service topicTrackingState;
  @service site;
  @service siteSettings;

  @tracked sections = [];

  constructor() {
    super(...arguments);
    this.messageBus.subscribe("/refresh-sidebar-sections", this._refresh);

    this.appEvents.on(
      REFRESH_CUSTOM_SIDEBAR_SECTIONS_APP_EVENT_NAME,
      this,
      this._refreshSections
    );

    this.#initSections();
  }

  willDestroy() {
    this.appEvents.off(
      REFRESH_CUSTOM_SIDEBAR_SECTIONS_APP_EVENT_NAME,
      this,
      this._refreshSections
    );

    this.messageBus.unsubscribe("/refresh-sidebar-sections");
    this.#teardown();
  }

  #teardown() {
    return this.sections.forEach((section) => {
      section.teardown?.();
    });
  }

  _refreshSections() {
    this.#teardown();
    this.#initSections();
  }

  #initSections() {
    this.sections = this.currentUser.sidebarSections.map((section) => {
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
      this.currentUser.updateSidebarSections(json.sidebar_sections);
    });
  }
}
