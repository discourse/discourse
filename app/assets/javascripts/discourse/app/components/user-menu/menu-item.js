import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class UserMenuItem extends Component {
  get className() {}

  get linkHref() {
    throw new Error("not implemented");
  }

  get linkTitle() {
    throw new Error("not implemented");
  }

  get icon() {
    throw new Error("not implemented");
  }

  get label() {
    throw new Error("not implemented");
  }

  get labelClass() {}

  get description() {
    throw new Error("not implemented");
  }

  get descriptionClass() {}

  get topicId() {}

  @action
  onClick() {}
}
