import Component from "@glimmer/component";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";
import RouteInfoHelper from "discourse/lib/sidebar/route-info-helper";

export default class SidebarUserCustomSections extends Component {
  @service currentUser;
  @service router;

  get sections() {
    this.currentUser.sidebarSections.forEach((section) => {
      section.links.forEach((link) => {
        const routeInfoHelper = new RouteInfoHelper(this.router, link.value);
        link.route = routeInfoHelper.route;
        link.models = routeInfoHelper.models;
        link.query = routeInfoHelper.query;
      });
    });
    return this.currentUser.sidebarSections;
  }

  @action
  editSection(section) {
    showModal("sidebar-section-form", { model: section });
  }
}
