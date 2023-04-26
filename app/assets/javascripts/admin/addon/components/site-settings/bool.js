import { computed } from "@ember/object";
import Component from "@ember/component";
import { isEmpty } from "@ember/utils";

export default class Bool extends Component {
  @computed("value")
  get enabled() {
    if (isEmpty(this.value)) {
      return false;
    }
    return this.value.toString() === "true";
  }

  set enabled(value) {
    this.set("value", value ? "true" : "false");
    return value;
  }
}
