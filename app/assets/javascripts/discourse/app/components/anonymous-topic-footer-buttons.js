import Component from "@ember/component";
import { computed } from "@ember/object";
import { getTopicFooterButtons } from "discourse/lib/register-topic-footer-button";

export default Component.extend({
  elementId: "topic-footer-buttons",

  attributeBindings: ["role"],

  role: "region",

  allButtons: getTopicFooterButtons(),

  @computed("allButtons.[]")
  get buttons() {
    return this.allButtons
      .filterBy("anonymousOnly", true)
      .sortBy("priority")
      .reverse();
  },
});
