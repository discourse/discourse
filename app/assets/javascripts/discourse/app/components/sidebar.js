import Component from "@glimmer/component";
import { bind } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default class Sidebar extends Component {
  @service appEvents;
  @service site;
  @service currentUser;

  constructor() {
    super(...arguments);

    if (this.site.mobileView) {
      document.addEventListener("click", this.collapseSidebar);
    }
  }

  @bind
  collapseSidebar(event) {
    let shouldCollapseSidebar = false;

    const isClickWithinSidebar = event.composedPath().some((element) => {
      if (
        element?.className !== "sidebar-section-header-caret" &&
        ["A", "BUTTON"].includes(element.nodeName)
      ) {
        shouldCollapseSidebar = true;
        return true;
      }

      return element.className && element.className === "sidebar-wrapper";
    });

    if (shouldCollapseSidebar || !isClickWithinSidebar) {
      this.args.toggleSidebar();
    }
  }

  get enableMessagesSection() {
    return (
      this.siteSettings.enable_personal_messages ||
      this.currentUser.staff ||
      this.currentUser.isInAnyGroups(
        this.siteSettings.personal_message_enabled_groups
          .split("|")
          .map((groupId) => parseInt(groupId, 10))
      )
    );
  }

  willDestroy() {
    if (this.site.mobileView) {
      document.removeEventListener("click", this.collapseSidebar);
    }
  }
}
