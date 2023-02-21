import Component from "@glimmer/component";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";
import RouteInfoHelper from "discourse/lib/sidebar/route-info-helper";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { iconHTML } from "discourse-common/lib/icon-library";
import { htmlSafe } from "@ember/template";
import { bind } from "discourse-common/utils/decorators";

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
    this.currentUser.sidebarSections.forEach((section) => {
      if (!section.public || this.currentUser.staff) {
        section.headerActions = [
          {
            action: () => {
              return showModal("sidebar-section-form", { model: section });
            },
            title: I18n.t("sidebar.sections.custom.edit"),
          },
        ];
      }
      section.decoratedTitle =
        section.public && this.currentUser.staff
          ? htmlSafe(`${iconHTML("globe")} ${section.title}`)
          : section.title;
      section.links.forEach((link) => {
        const routeInfoHelper = new RouteInfoHelper(this.router, link.value);
        link.route = routeInfoHelper.route;
        link.models = routeInfoHelper.models;
        link.query = routeInfoHelper.query;
      });
    });
    return this.currentUser.sidebarSections;
  }

  @bind
  _refresh() {
    return ajax("/sidebar_sections.json", {}).then((json) => {
      this.currentUser.set("sidebar_sections", json.sidebar_sections);
    });
  }
}
