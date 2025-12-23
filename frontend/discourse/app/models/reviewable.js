import { computed } from "@ember/object";
import { dasherize, underscore } from "@ember/string";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import RestModel from "discourse/models/rest";
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

  @computed("type", "topic")
  get resolvedType() {
    // Display "Queued Topic" if the post will create a topic
    if (this.type === "ReviewableQueuedPost" && !this.topic) {
      return "ReviewableQueuedTopic";
    }

    return this.type;
  }

  @computed("resolvedType")
  get humanType() {
    return i18n(`review.types.${underscore(this.resolvedType)}.title`, {
      defaultValue: "",
    });
  }

  @computed("humanType")
  get humanTypeCssClass() {
    return "-" + dasherize(this.humanType);
  }

  @computed("resolvedType")
  get humanNoun() {
    return i18n(`review.types.${underscore(this.resolvedType)}.noun`, {
      defaultValue: "reviewable",
    });
  }

  @computed("humanNoun")
  get flaggedReviewableContextQuestion() {
    const uniqueReviewableScores = uniqueItemsFromArray(
      this.reviewable_scores,
      "score_type.type"
    );

    if (uniqueReviewableScores.length === 1) {
      if (uniqueReviewableScores[0].score_type.type === "notify_moderators") {
        return i18n("review.context_question.something_else_wrong", {
          reviewable_type: this.humanNoun,
        });
      }
    }

    const listOfQuestions = I18n.listJoiner(
      uniqueItemsFromArray(
        uniqueReviewableScores.map((score) =>
          score.score_type.title.toLowerCase()
        )
      ),
      i18n("review.context_question.delimiter")
    );

    return i18n("review.context_question.is_this_post", {
      reviewable_human_score_types: listOfQuestions,
      reviewable_type: this.humanNoun,
    });
  }

  @computed("category_id")
  get category() {
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
