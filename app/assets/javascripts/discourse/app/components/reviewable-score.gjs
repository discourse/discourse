import Component from "@ember/component";
import { gt } from "@ember/object/computed";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";

@tagName("")
export default class ReviewableScore extends Component {
  @gt("rs.status", 0) showStatus;

  @discourseComputed("rs.score_type.title", "reviewable.target_created_by")
  title(title, targetCreatedBy) {
    if (title && targetCreatedBy) {
      return title.replace(
        /{{username}}|%{username}/,
        targetCreatedBy.username
      );
    }

    return title;
  }
}
