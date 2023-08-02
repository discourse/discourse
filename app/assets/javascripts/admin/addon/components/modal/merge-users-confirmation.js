import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

export default class MergeUsersConfirmation extends Component {
  @tracked value;

  get mergeDisabled() {
    return !this.value || this.text !== this.value;
  }

  get text() {
    return I18n.t("admin.user.merge.confirmation.text", {
      username: this.args.model.username,
      targetUsername: this.args.model.targetUsername,
    });
  }
}
