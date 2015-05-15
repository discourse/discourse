export default Em.View.extend({
  templateName: "poll",
  classNames: ["poll"],
  attributeBindings: ["data-poll-type", "data-poll-name", "data-poll-status"],

  poll: Em.computed.alias("controller.poll"),

  "data-poll-type": Em.computed.alias("poll.type"),
  "data-poll-name": Em.computed.alias("poll.name"),
  "data-poll-status": Em.computed.alias("poll.status"),

  _fixPollContainerHeight: function() {
    const pollContainer = this.$(".poll-container");
    pollContainer.height(pollContainer.height());
  }.on("didInsertElement")
});
