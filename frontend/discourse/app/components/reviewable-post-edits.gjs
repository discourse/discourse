/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { gt } from "@ember/object/computed";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import HistoryModal from "discourse/components/modal/history";
import { historyHeat } from "discourse/components/post/meta-data/edits-indicator";
import { longDate } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";

export default class ReviewablePostEdits extends Component {
  @service modal;

  @gt("reviewable.post_version", 1) hasEdits;

  @computed("reviewable.post_version")
  get editCount() {
    return this.reviewable?.post_version - 1;
  }

  @computed("reviewable.post_updated_at")
  get historyClass() {
    return historyHeat(this.siteSettings, new Date(this.reviewable?.post_updated_at));
  }

  @computed("reviewable.post_updated_at")
  get editedDate() {
    return longDate(this.reviewable?.post_updated_at);
  }

  @computed("reviewable.post_updated_at")
  get editedTitle() {
    return i18n("post.last_edited_on", { dateTime: longDate(this.reviewable?.post_updated_at) });
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
      <div class="post-info edits">
        <DButton
          @action={{this.showEditHistory}}
          @icon="pencil"
          @translatedLabel={{this.editCount}}
          @translatedTitle={{this.editedTitle}}
          class="btn-icon-text btn-flat {{this.historyClass}}"
        />
      </div>
    {{/if}}
  </template>
}
