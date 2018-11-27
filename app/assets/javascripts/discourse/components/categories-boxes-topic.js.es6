import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "li",

  @computed("topic.pinned", "topic.closed", "topic.archived")
  topicStatusIcon(pinned, closed, archived) {
    if (pinned) {
      return "thumbtack";
    }
    if (closed || archived) {
      return "lock";
    }
    return "far-file-alt";
  }
});
