export default Em.View.extend({
  templateName: "poll",
  classNames: ["poll"],
  attributeBindings: ["data-poll-type", "data-poll-id", "data-poll-status", "data-poll-public"],

  poll: Em.computed.alias("controller.poll"),

  "data-poll-type": Em.computed.alias("poll.type"),
  "data-poll-id": Em.computed.alias("poll.id"),
  "data-poll-status": Em.computed.alias("poll.status"),
  "data-poll-public": Em.computed.alias("poll.public")
});
