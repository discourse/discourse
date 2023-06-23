import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class extends Component {
  @tracked filter = "";

  get modalHeaderAfterTitleElement() {
    return document.getElementById("modal-header-after-title");
  }

  @action
  onFilterInput(value) {
    this.args.onFilterInput(value);
  }
}
