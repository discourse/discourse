import Component from "@ember/component";
import { computed } from "@ember/object";
import { attributeBindings } from "@ember-decorators/component";
import { getTopicFooterButtons } from "discourse/lib/register-topic-footer-button";

@attributeBindings("role")
export default class AnonymousTopicFooterButtons extends Component {
  elementId = "topic-footer-buttons";
  role = "region";

  @getTopicFooterButtons() allButtons;

  @computed("allButtons.[]")
  get buttons() {
    return this.allButtons
      .filterBy("anonymousOnly", true)
      .sortBy("priority")
      .reverse();
  }
}
