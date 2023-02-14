import Component from "@glimmer/component";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";
import RouteInfoHelper from "discourse/lib/sidebar/route-info-helper";
import I18n from "I18n";

export default class SidebarUserCustomSections extends Component {
  @service currentUser;
  @service router;

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
      section.links.forEach((link) => {
        const routeInfoHelper = new RouteInfoHelper(this.router, link.value);
        link.route = routeInfoHelper.route;
        link.models = routeInfoHelper.models;
        link.query = routeInfoHelper.query;
      });
    });
    return this.currentUser.sidebarSections;
  }
}
