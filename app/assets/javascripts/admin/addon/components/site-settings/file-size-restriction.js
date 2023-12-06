import Component from "@ember/component";
import { action } from "@ember/object";

export default class FileSizeRestriction extends Component {
  @action
  onChangeSize(size) {
    //this.set("validationMessage", "asdfasdf");
    this.set("value", size);
  }

  @action
  updateValidationMessage(message) {
    this.set("validationMessage", message);
  }
}
