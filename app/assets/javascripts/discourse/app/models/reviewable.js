import categoryFromId from "discourse-common/utils/category-macro";
import I18n from "I18n";
import { Promise } from "rsvp";
import RestModel from "discourse/models/rest";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";

export const PENDING = 0;
export const APPROVED = 1;
export const REJECTED = 2;
export const IGNORED = 3;
export const DELETED = 4;

const Reviewable = RestModel.extend({
  @discourseComputed("type", "topic")
  humanType(type, topic) {
    // Display "Queued Topic" if the post will create a topic
    if (type === "ReviewableQueuedPost" && !topic) {
      type = "ReviewableQueuedTopic";
    }

    return I18n.t(`review.types.${type.underscore()}.title`, {
      defaultValue: "",
    });
  },

  category: categoryFromId("category_id"),

  update(updates) {
    // If no changes, do nothing
    if (Object.keys(updates).length === 0) {
      return Promise.resolve();
    }

    let adapter = this.store.adapterFor("reviewable");
    return ajax(
      `/review/${this.id}?version=${this.version}`,
      adapter.getPayload("PUT", { reviewable: updates })
    ).then((updated) => {
      updated.payload = Object.assign(
        {},
        this.payload || {},
        updated.payload || {}
      );

      this.setProperties(updated);
    });
  },
});

Reviewable.reopenClass({
  munge(json) {
    // ensure we are not overriding category computed property
    delete json.category;
    return json;
  },
});

export default Reviewable;
