import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

export default class MergeUsersPrompt extends Component {
  @tracked targetUsername;

  get mergeDisabled() {
    return (
      !this.targetUsername ||
      this.args.model.user.username === this.targetUsername[0]
    );
  }
}
