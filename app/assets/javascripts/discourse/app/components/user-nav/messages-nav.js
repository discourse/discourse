import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class UserNavMessagesNav extends Component {
  @service site;

  get messagesDropdownvalue() {
    switch (this.args.currentRouteName) {
      case "userPrivateMessages.tags":
      case "userPrivateMessages.tags.index":
      case "userPrivateMessages.tags.show":
        return "tags";
      default:
        if (this.args.groupFilter) {
          return this.args.groupFilter;
        } else {
          return "inbox";
        }
    }
  }

  get displayTags() {
    return this.args.pmTaggingEnabled && this.messagesDropdownvalue === "tags";
  }
}
