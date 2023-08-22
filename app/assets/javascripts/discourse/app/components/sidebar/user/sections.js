import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class SidebarUserSections extends Component {
  @service siteSettings;
  @service currentUser;
  @service site;

  get enableMessagesSection() {
    return this.currentUser?.can_send_private_messages;
  }
}
