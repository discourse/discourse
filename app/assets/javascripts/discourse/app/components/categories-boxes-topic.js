import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",

  @discourseComputed("topic.pinned", "topic.closed", "topic.archived")
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
