import { dasherize, underscore } from "@ember/string";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";
import discourseComputed from "discourse-common/utils/decorators";
import I18n, { i18n } from "discourse-i18n";
import Category from "./category";

export const PENDING = 0;
export const APPROVED = 1;
export const REJECTED = 2;
export const IGNORED = 3;
export const DELETED = 4;

export default class Reviewable extends RestModel {
  static munge(json) {
    // ensure we are not overriding category computed property
    delete json.category;
    return json;
  }

  @discourseComputed("type", "topic")
  resolvedType(type, topic) {
    // Display "Queued Topic" if the post will create a topic
    if (type === "ReviewableQueuedPost" && !topic) {
      return "ReviewableQueuedTopic";
    }

    return type;
  }

  @discourseComputed("resolvedType")
  humanType(resolvedType) {
    return i18n(`review.types.${underscore(resolvedType)}.title`, {
      defaultValue: "",
    });
  }

  @discourseComputed("humanType")
  humanTypeCssClass(humanType) {
    return "-" + dasherize(humanType);
  }

  @discourseComputed("resolvedType")
  humanNoun(resolvedType) {
    return i18n(`review.types.${underscore(resolvedType)}.noun`, {
      defaultValue: "reviewable",
    });
  }

  @discourseComputed("humanNoun")
  flaggedReviewableContextQuestion(humanNoun) {
    const uniqueReviewableScores =
      this.reviewable_scores.uniqBy("score_type.type");

    if (uniqueReviewableScores.length === 1) {
      if (uniqueReviewableScores[0].score_type.type === "notify_moderators") {
        return i18n("review.context_question.something_else_wrong", {
          reviewable_type: humanNoun,
        });
      }
    }

    const listOfQuestions = I18n.listJoiner(
      uniqueReviewableScores
        .map((score) => score.score_type.title.toLowerCase())
        .uniq(),
      i18n("review.context_question.delimiter")
    );

    return i18n("review.context_question.is_this_post", {
      reviewable_human_score_types: listOfQuestions,
      reviewable_type: humanNoun,
    });
  }

  @discourseComputed("category_id")
  category() {
    return Category.findById(this.category_id);
  }

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
  }
}
