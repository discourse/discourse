import Component from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { gt } from "@ember/object/computed";
import { service } from "@ember/service";
import HistoryModal from "discourse/components/modal/history";
import icon from "discourse/helpers/d-icon";
import discourseComputed from "discourse/lib/decorators";
import { longDate } from "discourse/lib/formatter";
import { historyHeat } from "discourse/widgets/post-edits-indicator";
import { i18n } from "discourse-i18n";

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

  <template>
    {{#if this.hasEdits}}
      <a
        href
        {{on "click" this.showEditHistory}}
        class="has-edits {{this.historyClass}}"
        title={{i18n "post.last_edited_on" dateTime=this.editedDate}}
      >
        {{icon "pencil"}}
      </a>
    {{/if}}
  </template>
}
