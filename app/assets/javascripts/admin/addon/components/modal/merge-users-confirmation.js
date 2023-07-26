import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class MergeUsersConfirmation extends Component {
  @tracked value = null;

  get mergeDisabled() {
    return !this.value || this.text !== this.value;
  }

  @action
  confirm() {
    this.args.model.merge(this.args.model.targetUsername);
    this.args.closeModal();
  }
}
