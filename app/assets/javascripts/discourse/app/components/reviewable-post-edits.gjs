import Component from "@ember/component";
import { action } from "@ember/object";
import { gt } from "@ember/object/computed";
import { service } from "@ember/service";
import HistoryModal from "discourse/components/modal/history";
import discourseComputed from "discourse/lib/decorators";
import { longDate } from "discourse/lib/formatter";
import { historyHeat } from "discourse/widgets/post-edits-indicator";

export default class ReviewablePostEdits extends Component {
  @service modal;

  @gt("reviewable.post_version", 1) hasEdits;

  @discourseComputed("reviewable.post_updated_at")
  historyClass(updatedAt) {
    return historyHeat(this.siteSettings, new Date(updatedAt));
  }

  @discourseComputed("reviewable.post_updated_at")
  editedDate(updatedAt) {
    return longDate(updatedAt);
  }

  @action
  showEditHistory(event) {
    event?.preventDefault();
    let postId = this.get("reviewable.post_id");
    this.store.find("post", postId).then((post) => {
      this.modal.show(HistoryModal, {
        model: {
          post,
          postId,
          postVersion: "latest",
          topicController: null,
        },
      });
    });
  }
}
