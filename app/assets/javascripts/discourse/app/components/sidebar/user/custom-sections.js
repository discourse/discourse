import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse-common/utils/decorators";
import Section from "discourse/components/sidebar/user/section";

export default class SidebarUserCustomSections extends Component {
  @service currentUser;
  @service router;
  @service messageBus;

  constructor() {
    super(...arguments);
    this.messageBus.subscribe("/refresh-sidebar-sections", this._refresh);
  }

  willDestroy() {
    this.messageBus.unsubscribe("/refresh-sidebar-sections");
  }

  get sections() {
    return this.currentUser.sidebarSections.map((section) => {
      return new Section({
        section,
        currentUser: this.currentUser,
        router: this.router,
      });
    });
  }

  get canReorder() {
    return document
      .getElementsByTagName("html")[0]
      .classList.contains("no-touch");
  }

  @bind
  _refresh() {
    return ajax("/sidebar_sections.json", {}).then((json) => {
      this.currentUser.set("sidebar_sections", json.sidebar_sections);
    });
  }
}
