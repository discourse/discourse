import Component from "@ember/component";
import { action } from "@ember/object";
import discourseComputed from "discourse/lib/decorators";

export default class TagList extends Component {
  @discourseComputed("value")
  selectedTags(value) {
    return value.split("|").filter(Boolean);
  }

  @action
  changeSelectedTags(tags) {
    this.set("value", tags.join("|"));
  }
}
