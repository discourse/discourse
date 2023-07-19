import I18n from "I18n";
import RawHtml from "discourse/widgets/raw-html";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";

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

export default createWidget("toggle-topic-summary", {
  tagName: "section.information.toggle-summary",
  buildKey: (attrs) => `toggle-topic-summary-${attrs.topicId}`,

  defaultState() {
    return {
      expandSummaryBox: false,
      summaryBoxHidden: true,
      summary: "",
      summarizedOn: null,
      summarizedBy: null,
    };
  },

  html(attrs, state) {
    const html = [];
    const summarizationButtons = [];

    if (attrs.summarizable) {
      const expandTitle = I18n.t("summary.strategy.button_title");
      const collapseTitle = I18n.t("summary.strategy.hide_button_title");
      const canCollapse = !this.loadingSummary() && this.summaryBoxVisble();

      summarizationButtons.push(
        this.attach("button", {
          className: "btn btn-primary topic-strategy-summarization",
          icon: canCollapse ? "chevron-up" : "magic",
          translatedTitle: canCollapse ? collapseTitle : expandTitle,
          translatedLabel: canCollapse ? collapseTitle : expandTitle,
          action: state.expandSummaryBox
            ? "toggleSummaryBox"
            : "expandSummaryBox",
          disabled: this.loadingSummary(),
        })
      );
    }

    if (attrs.hasTopRepliesSummary) {
      html.push(this.attach("toggle-summary-description", attrs));
      summarizationButtons.push(
        this.attach("button", {
          className: "btn top-replies",
          icon: attrs.topicSummaryEnabled ? null : "layer-group",
          title: attrs.topicSummaryEnabled ? null : "summary.short_title",
          label: attrs.topicSummaryEnabled
            ? "summary.disable"
            : "summary.enable",
          action: attrs.topicSummaryEnabled ? "cancelFilter" : "showTopReplies",
        })
      );
    }

    if (summarizationButtons) {
      html.push(h("div.summarization-buttons", summarizationButtons));
    }

    if (this.summaryBoxVisble()) {
      attrs.summary = this.state.summary;
      attrs.summarizedOn = this.state.summarizedOn;
      attrs.summarizedBy = this.state.summarizedBy;
      html.push(this.attach("summary-box", attrs));
    }

    return html;
  },

  loadingSummary() {
    return this.summaryBoxVisble() && !this.state.summary;
  },

  summaryUpdatedEvent(update) {
    this.state.summary = update.summary;
    this.state.summarizedOn = update.summarizedOn;
    this.state.summarizedBy = update.summarizedBy;
  },

  summaryBoxVisble() {
    return this.state.expandSummaryBox && !this.state.summaryBoxHidden;
  },

  expandSummaryBox() {
    this.state.expandSummaryBox = true;
    this.state.summaryBoxHidden = false;
  },

  toggleSummaryBox() {
    this.state.summaryBoxHidden = !this.state.summaryBoxHidden;
  },
});
