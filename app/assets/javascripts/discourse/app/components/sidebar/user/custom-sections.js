import Component from "@glimmer/component";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";

export default class SidebarUserCustomSections extends Component {
  @service currentUser;

  constructor() {
    super(...arguments);

    this.sections.forEach((section) => {
      section.links.forEach((link) => {
        link.class = window.location.pathname === link.value ? "active" : "";
      });
    });
  }

  get sections() {
    return this.currentUser.sidebar_sections || [];
  }

  @action
  editSection(section) {
    showModal("sidebar-section-form", { model: section });
  }

  addSection() {
    showModal("sidebar-section-form");
  }
}
