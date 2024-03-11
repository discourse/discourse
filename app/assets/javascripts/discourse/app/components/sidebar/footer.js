import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";

export default class SidebarFooter extends Component {
  @service capabilities;
  @service currentUser;
  @service modal;
  @service site;
  @service siteSettings;

  @action
  addSection() {
    this.modal.show(SidebarSectionForm);
  }
}
