import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class CreateInviteBulk extends Component {
  @tracked data;

  @action
  submit(data) {
    this.data = data;
    this.data.submit();
  }

  willDestroy() {
    if (this.data) {
      this.data.abort();
      this.data = null;
    }
  }
}
