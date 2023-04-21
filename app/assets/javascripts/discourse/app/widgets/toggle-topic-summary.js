import I18n from "I18n";
import RawHtml from "discourse/widgets/raw-html";
import { createWidget } from "discourse/widgets/widget";

const MIN_POST_READ_TIME = 4;

createWidget("toggle-summary-description", {
  description(attrs) {
    if (attrs.topicSummaryEnabled) {
      return I18n.t("summary.enabled_description");
    }

    if (attrs.topicWordCount && this.siteSettings.read_time_word_count > 0) {
      const readingTime = Math.ceil(
        Math.max(
          attrs.topicWordCount / this.siteSettings.read_time_word_count,
          (attrs.topicPostsCount * MIN_POST_READ_TIME) / 60
        )
      );
      return I18n.messageFormat("summary.description_time_MF", {
        replyCount: attrs.topicReplyCount,
        readingTime,
      });
    }
    return I18n.t("summary.description", { count: attrs.topicReplyCount });
  },

  html(attrs) {
    // vdom makes putting html in the i18n difficult
    return new RawHtml({ html: `<p>${this.description(attrs)}</p>` });
  },
});

let topicSummaryCallbacks = null;
export function addTopicSummaryCallback(callback) {
  topicSummaryCallbacks = topicSummaryCallbacks || [];
  topicSummaryCallbacks.push(callback);
}

export default createWidget("toggle-topic-summary", {
  tagName: "section.information.toggle-summary",
  html(attrs) {
    let html = [
      this.attach("toggle-summary-description", attrs),
      this.attach("button", {
        className: "btn btn-primary",
        icon: attrs.topicSummaryEnabled ? null : "layer-group",
        title: attrs.topicSummaryEnabled ? null : "summary.short_title",
        label: attrs.topicSummaryEnabled ? "summary.disable" : "summary.enable",
        action: attrs.topicSummaryEnabled ? "cancelFilter" : "showSummary",
      }),
    ];

    if (topicSummaryCallbacks) {
      topicSummaryCallbacks.forEach((callback) => {
        html = callback(html, attrs, this);
      });
    }

    return html;
  },
});
