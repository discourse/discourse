import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  tagName: "",

  showStatus: Ember.computed.gt("rs.status", 0),

  @computed("rs.score_type.title", "reviewable.target_created_by")
  title(title, targetCreatedBy) {
    if (title && targetCreatedBy) {
      return title.replace("{{username}}", targetCreatedBy.username);
    }

    return title;
  }
});
