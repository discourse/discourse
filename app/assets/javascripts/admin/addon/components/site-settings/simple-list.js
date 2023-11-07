import Component from "@ember/component";
import { action } from "@ember/object";

export default class SimpleList extends Component {
  inputDelimiter = "|";

  @__action__
  onChange(value) {
    this.set("value", value.join(this.inputDelimiter || "\n"));
  }
}
