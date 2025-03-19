import Component from "@ember/component";
import { action } from "@ember/object";

export default class ReviewableFieldTags extends Component {
  @action
  onChange(tags) {
    this.set("value", tags);

    this.valueChanged &&
      this.valueChanged({
        target: {
          value: tags,
        },
      });
  }
}
