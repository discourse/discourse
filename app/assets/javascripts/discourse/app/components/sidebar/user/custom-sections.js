import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse-common/utils/decorators";
import Section from "discourse/components/sidebar/user/section";
import SystemSection from "discourse/components/sidebar/common/system-section";

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
    this.callbackIds = [];
  }

  willDestroy() {
    this.messageBus.unsubscribe("/refresh-sidebar-sections");
    this.callbackIds.forEach((id) => {
      this.topicTrackingState.offStateChange(id);
    });
    return this.sections.forEach((section) => {
      section.teardown?.();
    });
  }

  get sections() {
    return this.currentUser.sidebarSections.map((section) => {
      if (section.system_section) {
        const systemSection = new SystemSection({
          section,
          currentUser: this.currentUser,
          router: this.router,
          appEvents: this.appEvents,
          topicTrackingState: this.topicTrackingState,
          siteSettings: this.siteSettings,
        });
        this.callbackIds.push(systemSection.callbackId);
        return systemSection;
      } else {
        return new Section({
          section,
          currentUser: this.currentUser,
          router: this.router,
        });
      }
    });
  }

  @bind
  _refresh() {
    return ajax("/sidebar_sections.json", {}).then((json) => {
      this.currentUser.set("sidebar_sections", json.sidebar_sections);
    });
  }
}
