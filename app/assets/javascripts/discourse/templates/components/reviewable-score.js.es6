import discourseComputed from "discourse-common/utils/decorators";
import { gt } from "@ember/object/computed";
import Component from "@ember/component";

export default Component.extend({
  tagName: "",

  showStatus: gt("rs.status", 0),

  @discourseComputed("rs.score_type.title", "reviewable.target_created_by")
  title(title, targetCreatedBy) {
    if (title && targetCreatedBy) {
      return title.replace("{{username}}", targetCreatedBy.username);
    }

    return title;
  }
});
