import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { smartShortDate } from "discourse/lib/formatter";
import { cook } from "discourse/lib/text";
import { isAiCreditLimitError, popupAiCreditLimitError } from "./ai-errors";

export default class AiTopicSummary {
  @tracked text = "";
  @tracked summarizedOn = null;
  @tracked summarizedBy = null;
  @tracked newPostsSinceSummary = null;
  @tracked outdated = false;
  @tracked canRegenerate = false;
  @tracked regenerated = false;

  @tracked showSummaryBox = false;
  @tracked canCollapseSummary = false;
  @tracked loadingSummary = false;

  processUpdate(update) {
    const topicSummary = update.ai_topic_summary;

    return cook(topicSummary.summarized_text)
      .then((cooked) => {
        this.text = cooked;
        this.loading = false;
      })
      .then(() => {
        if (update.done) {
          this.summarizedOn = smartShortDate(
            new Date(topicSummary.summarized_on)
          );
          this.summarizedBy = topicSummary.algorithm;
          this.newPostsSinceSummary = topicSummary.new_posts_since_summary;
          this.outdated = topicSummary.outdated;
          this.newPostsSinceSummary = topicSummary.new_posts_since_summary;
          this.canRegenerate =
            topicSummary.outdated && topicSummary.can_regenerate;
        }
      });
  }

  collapse() {
    this.showSummaryBox = false;
    this.canCollapseSummary = false;
  }

  generateSummary(currentUser, topicId) {
    this.showSummaryBox = true;

    if (this.text && !this.canRegenerate) {
      this.canCollapseSummary = false;
      return;
    }

    let fetchURL = `/discourse-ai/summarization/t/${topicId}`;
    let ajaxOpts = {};

    if (currentUser) {
      ajaxOpts.type = "POST";
      ajaxOpts.data = { stream: true };

      if (this.canRegenerate) {
        ajaxOpts.data.skip_age_check = true;
      }
    }

    this.loading = true;

    return ajax(fetchURL, ajaxOpts)
      .then((data) => {
        if (!currentUser) {
          data.done = true;
          this.processUpdate(data);
        }
      })
      .catch((error) => {
        this.loading = false;
        if (isAiCreditLimitError(error)) {
          popupAiCreditLimitError(error);
        } else {
          throw error;
        }
      });
  }
}
