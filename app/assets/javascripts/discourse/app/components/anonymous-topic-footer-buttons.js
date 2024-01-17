import Component from "@ember/component";
import { computed } from "@ember/object";
import { getTopicFooterButtons } from "discourse/lib/register-topic-footer-button";

export default Component.extend({
  elementId: "topic-footer-buttons",

  attributeBindings: ["role"],

  role: "region",

  allButtons: getTopicFooterButtons(),

  @computed("inlineButtons.[]")
  get buttons() {
    return this.allButtons
      .filterBy("displayForAnonymous", true)
      .sortBy("priority")
      .reverse();
  },
});
