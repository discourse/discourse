import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";

export default class SidebarFooter extends Component {
  @service capabilities;
  @service site;
  @service siteSettings;
  @service currentUser;

  @action
  addSection() {
    showModal("sidebar-section-form");
  }
}
