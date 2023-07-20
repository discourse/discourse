import Component from "@glimmer/component";
import { action, get } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class MergeUsersPrompt extends Component {
  @tracked targetUsername = null;

  get mergeDisabled() {
    return (
      !this.targetUsername || this.args.model.username === this.targetUsername
    );
  }

  @action
  showConfirmation() {
    this.args.model.showMergeConfirmation(this.targetUsername);
    this.args.closeModal();
  }

  @action
  updateUsername(selected) {
    this.targetUsername = get(selected, "firstObject");
  }
}
