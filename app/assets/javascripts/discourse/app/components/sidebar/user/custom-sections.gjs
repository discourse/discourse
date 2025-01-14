import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import SidebarCustomSections from "../common/custom-sections";

export default class SidebarUserCustomSections extends SidebarCustomSections {
  constructor() {
    super(...arguments);
    this.messageBus.subscribe("/refresh-sidebar-sections", this._refresh);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe("/refresh-sidebar-sections");
  }

  @bind
  async _refresh() {
    const json = await ajax("/sidebar_sections.json", {});
    this.currentUser.set("sidebar_sections", json.sidebar_sections);
  }
}
