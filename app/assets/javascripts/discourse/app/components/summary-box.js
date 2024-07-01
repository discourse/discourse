import Component from "@glimmer/component";
import { service } from "@ember/service";
import I18n from "discourse-i18n";

export default class SummaryBox extends Component {
  @service siteSettings;

  get summary() {
    return this.args.postStream.topicSummary;
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
      !this.topRepliesSummaryEnabled &&
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
    return this.args.postStream.summary;
  }
}
