import SidebarCustomSection from "discourse/components/sidebar/common/custom-sections";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse-common/utils/decorators";

export default class SidebarUserCustomSections extends SidebarCustomSection {
  constructor() {
    super(...arguments);

    this.messageBus.subscribe("/refresh-sidebar-sections", this._refresh);
  }

  willDestroy() {
    this.messageBus.unsubscribe("/refresh-sidebar-sections");
  }

  @bind
  _refresh() {
    return ajax("/sidebar_sections.json", {}).then((json) => {
      this.currentUser.set("sidebar_sections", json.sidebar_sections);
    });
  }
}
