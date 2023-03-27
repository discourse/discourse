import Component from "@ember/component";
import { computed } from "@ember/object";
import { formatUsername } from "discourse/lib/utilities";

export default class ChatUserDisplayName extends Component {
  tagName = "";
  user = null;

  @computed
  get shouldPrioritizeNameInUx() {
    return !this.siteSettings.prioritize_username_in_ux;
  }

  @computed("user.name")
  get hasValidName() {
    return this.user?.name && this.user?.name.trim().length > 0;
  }

  @computed("user.username")
  get formattedUsername() {
    return formatUsername(this.user?.username);
  }

  @computed("shouldPrioritizeNameInUx", "hasValidName")
  get shouldShowNameFirst() {
    return this.shouldPrioritizeNameInUx && this.hasValidName;
  }

  @computed("shouldPrioritizeNameInUx", "hasValidName")
  get shouldShowNameLast() {
    return !this.shouldPrioritizeNameInUx && this.hasValidName;
  }
}
