import Component from "@ember/component";
import { gt } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",

  showStatus: gt("rs.status", 0),

  @discourseComputed("rs.score_type.title", "reviewable.target_created_by")
  title(title, targetCreatedBy) {
    if (title && targetCreatedBy) {
      return title.replace(
        /{{username}}|%{username}/,
        targetCreatedBy.username
      );
    }

    return title;
  },
});
