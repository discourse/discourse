import Component from "@ember/component";
import { action } from "@ember/object";

export default class FileSizeRestriction extends Component {
  @action
  onChangeSize(size) {
    this.set("value", size);
  }
}
