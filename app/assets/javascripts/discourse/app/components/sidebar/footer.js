import Component from "@glimmer/component";
import { getOwner } from "discourse-common/lib/get-owner";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";

export default class SidebarFooter extends Component {
  @service site;
  @service siteSettings;

  get capabilities() {
    return getOwner(this).lookup("capabilities:main");
  }

  @action
  addSection() {
    showModal("sidebar-section-form");
  }
}
