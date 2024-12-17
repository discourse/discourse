import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class CreateTopicButton extends Component {
  label = "topic.create";
  btnClass = "btn-default";

  get disallowedReason() {
    if (this.canCreateTopicOnTag === false) {
      return "topic.create_disabled_tag";
    } else if (this.disabled) {
      return "topic.create_disabled_category";
    }
  }
}
