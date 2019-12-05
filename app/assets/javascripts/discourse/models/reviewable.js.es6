import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";
import Category from "discourse/models/category";
import { Promise } from "rsvp";

export const PENDING = 0;
export const APPROVED = 1;
export const REJECTED = 2;
export const IGNORED = 3;
export const DELETED = 4;

export default RestModel.extend({
  @discourseComputed("type", "topic")
  humanType(type, topic) {
    // Display "Queued Topic" if the post will create a topic
    if (type === "ReviewableQueuedPost" && !topic) {
      type = "ReviewableQueuedTopic";
    }

    return I18n.t(`review.types.${type.underscore()}.title`, {
      defaultValue: ""
    });
  },

  update(updates) {
    // If no changes, do nothing
    if (Object.keys(updates).length === 0) {
      return Promise.resolve();
    }

    let adapter = this.store.adapterFor("reviewable");
    return ajax(
      `/review/${this.id}?version=${this.version}`,
      adapter.getPayload("PUT", { reviewable: updates })
    ).then(updated => {
      updated.payload = Object.assign(
        {},
        this.payload || {},
        updated.payload || {}
      );

      if (updated.category_id) {
        updated.category = Category.findById(updated.category_id);
        delete updated.category_id;
      }

      this.setProperties(updated);
    });
  }
});
