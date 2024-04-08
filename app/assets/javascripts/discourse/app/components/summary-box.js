import Component from "@glimmer/component";
import { service } from "@ember/service";
import I18n from "discourse-i18n";

const MIN_POST_READ_TIME = 4;

export default class SummaryBox extends Component {
  @service siteSettings;

  get summary() {
    return this.args.postAttrs.summary;
  }

  get generateSummaryTitle() {
    const title = this.summary.canRegenerate
      ? "summary.buttons.regenerate"
      : "summary.buttons.generate";

    return I18n.t(title);
  }

  get generateSummaryIcon() {
    return this.summary.canRegenerate ? "sync" : "discourse-sparkles";
  }

  get outdatedSummaryWarningText() {
    let outdatedText = I18n.t("summary.outdated");

    if (
      !this.args.postAttrs.hasTopRepliesSummary &&
      this.summary.newPostsSinceSummary > 0
    ) {
      outdatedText += " ";
      outdatedText += I18n.t("summary.outdated_posts", {
        count: this.summary.newPostsSinceSummary,
      });
    }

    return outdatedText;
  }

  get topRepliesSummaryEnabled() {
    return this.args.postAttrs.topicSummaryEnabled;
  }

  get topRepliesSummaryInfo() {
    if (this.args.postAttrs.topicSummaryEnabled) {
      return I18n.t("summary.enabled_description");
    }

    const wordCount = this.args.postAttrs.topicWordCount;
    if (wordCount && this.siteSettings.read_time_word_count > 0) {
      const readingTime = Math.ceil(
        Math.max(
          wordCount / this.siteSettings.read_time_word_count,
          (this.args.postAttrs.topicPostsCount * MIN_POST_READ_TIME) / 60
        )
      );
      return I18n.messageFormat("summary.description_time_MF", {
        replyCount: this.args.postAttrs.topicReplyCount,
        readingTime,
      });
    }
    return I18n.t("summary.description", {
      count: this.args.postAttrs.topicReplyCount,
    });
  }

  get topRepliesTitle() {
    if (this.topRepliesSummaryEnabled) {
      return;
    }

    return I18n.t("summary.short_title");
  }

  get topRepliesLabel() {
    const label = this.topRepliesSummaryEnabled
      ? "summary.disable"
      : "summary.enable";

    return I18n.t(label);
  }

  get topRepliesIcon() {
    if (this.topRepliesSummaryEnabled) {
      return;
    }

    return "layer-group";
  }
}
