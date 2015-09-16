import { on } from "ember-addons/ember-computed-decorators";

export default Em.View.extend({
  templateName: "poll",
  classNames: ["poll"],
  attributeBindings: ["data-poll-type", "data-poll-name", "data-poll-status"],

  poll: Em.computed.alias("controller.poll"),

  "data-poll-type": Em.computed.alias("poll.type"),
  "data-poll-name": Em.computed.alias("poll.name"),
  "data-poll-status": Em.computed.alias("poll.status"),

  @on("didInsertElement")
  _fixPollContainerHeight() {
    const pollContainer = this.$(".poll-container");
    pollContainer.height(pollContainer.height());
  }
});
