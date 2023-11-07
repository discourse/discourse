import Component from "@ember/component";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default class TagList extends Component {
  @discourseComputed("value")
  selectedTags(value) {
    return value.split("|").filter(Boolean);
  }

  @__action__
  changeSelectedTags(tags) {
    this.set("value", tags.join("|"));
  }
}
