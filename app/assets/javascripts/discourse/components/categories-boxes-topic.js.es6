import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "li",
  classNameBindings: ["topicStatusIcon"],

  @computed("topic.pinned", "topic.closed", "topic.archived")
  topicStatusIcon(pinned, closed, archived) {
    if (pinned) {
      return "topic-pinned";
    }
    if (closed) {
      return "topic-closed";
    }
    if (archived) {
      return "topic-archived";
    }
    return "topic-open";
  }
});
