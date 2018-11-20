import RawHtml from "discourse/widgets/raw-html";
import { createWidget } from "discourse/widgets/widget";

createWidget("toggle-summary-description", {
  description(attrs) {
    if (attrs.topicSummaryEnabled) {
      return I18n.t("summary.enabled_description");
    }

    if (attrs.topicWordCount) {
      const readingTime = Math.floor(
        attrs.topicWordCount / this.siteSettings.read_time_word_count
      );
      return I18n.t("summary.description_time", {
        replyCount: attrs.topicReplyCount,
        readingTime
      });
    }
    return I18n.t("summary.description", { replyCount: attrs.topicReplyCount });
  },

  html(attrs) {
    // vdom makes putting html in the i18n difficult
    return new RawHtml({ html: `<p>${this.description(attrs)}</p>` });
  }
});

export default createWidget("toggle-topic-summary", {
  tagName: "section.information.toggle-summary",
  html(attrs) {
    return [
      this.attach("toggle-summary-description", attrs),
      this.attach("button", {
        className: "btn btn-primary",
        label: attrs.topicSummaryEnabled ? "summary.disable" : "summary.enable",
        action: "toggleSummary"
      })
    ];
  }
});
