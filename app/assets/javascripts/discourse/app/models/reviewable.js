import categoryFromId from "discourse-common/utils/category-macro";
import { dasherize, underscore } from "@ember/string";
import I18n from "I18n";
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
  resolvedType(type, topic) {
    // Display "Queued Topic" if the post will create a topic
    if (type === "ReviewableQueuedPost" && !topic) {
      return "ReviewableQueuedTopic";
    }

    return type;
  },

  @discourseComputed("resolvedType")
  humanType(resolvedType) {
    return I18n.t(`review.types.${underscore(resolvedType)}.title`, {
      defaultValue: "",
    });
  },

  @discourseComputed("humanType")
  humanTypeCssClass(humanType) {
    return "-" + dasherize(humanType);
  },

  @discourseComputed
  flaggedPostContextQuestion() {
    const uniqueReviewableScores =
      this.reviewable_scores.uniqBy("score_type.type");

    if (uniqueReviewableScores.length === 1) {
      if (uniqueReviewableScores[0].score_type.type === "notify_moderators") {
        return I18n.t("review.context_question.something_else_wrong");
      }
    }

    const listOfQuestions = I18n.listJoiner(
      uniqueReviewableScores
        .map((score) => score.score_type.title.toLowerCase())
        .uniq(),
      I18n.t("review.context_question.delimiter")
    );

    return I18n.t("review.context_question.is_this_post", {
      reviewable_human_score_types: listOfQuestions,
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
