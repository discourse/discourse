import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { i18n } from "discourse-i18n";

export default class MergeUsersConfirmation extends Component {
  @tracked value;

  get mergeDisabled() {
    return !this.value || this.text !== this.value;
  }

  get text() {
    return i18n("admin.user.merge.confirmation.text", {
      username: this.args.model.username,
      targetUsername: this.args.model.targetUsername,
    });
  }
}
