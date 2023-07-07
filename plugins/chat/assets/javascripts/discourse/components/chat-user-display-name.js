import Component from "@glimmer/component";
import { formatUsername } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";

export default class ChatUserDisplayName extends Component {
  @service siteSettings;

  get shouldPrioritizeNameInUx() {
    return !this.siteSettings.prioritize_username_in_ux;
  }

  get hasValidName() {
    return this.args.user?.name && this.args.user.name.trim().length > 0;
  }

  get formattedUsername() {
    return formatUsername(this.args.user?.username);
  }

  get shouldShowNameFirst() {
    return this.shouldPrioritizeNameInUx && this.hasValidName;
  }

  get shouldShowNameLast() {
    return !this.shouldPrioritizeNameInUx && this.hasValidName;
  }
}
