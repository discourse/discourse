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
      const canRegenerate =
        !state.regenerate &&
        state.summary.outdated &&
        state.summary.can_regenerate;
      const canCollapse =
        !canRegenerate && !this.loadingSummary() && this.summaryBoxVisble();
      const summarizeButton = canCollapse
        ? this.hideSummaryButton()
        : this.generateSummaryButton(canRegenerate);

      summarizationButtons.push(summarizeButton);
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
      attrs.summary = state.summary;
      attrs.skipAgeCheck = state.regenerate;

      html.push(this.attach("summary-box", attrs));
    }

    return html;
  },

  generateSummaryButton(canRegenerate) {
    const title = canRegenerate
      ? "summary.buttons.regenerate"
      : "summary.buttons.generate";
    const icon = canRegenerate ? "sync" : "magic";

    return this.attach("button", {
      className: "btn btn-primary topic-strategy-summarization",
      icon,
      title: I18n.t(title),
      translatedTitle: I18n.t(title),
      translatedLabel: I18n.t(title),
      action: canRegenerate ? "regenerateSummary" : "expandSummaryBox",
      disabled: this.loadingSummary(),
    });
  },

  hideSummaryButton() {
    return this.attach("button", {
      className: "btn btn-primary topic-strategy-summarization",
      icon: "chevron-up",
      title: "summary.buttons.hide",
      label: "summary.buttons.hide",
      action: "toggleSummaryBox",
      disabled: this.loadingSummary(),
    });
  },

  loadingSummary() {
    return (
      this.summaryBoxVisble() && (!this.state.summary || this.state.regenerate)
    );
  },

  summaryUpdatedEvent(summary) {
    this.state.summary = summary;

    if (summary.regenerated) {
      this.state.regenerate = false;
    }
  },

  summaryBoxVisble() {
    return this.state.expandSummaryBox && !this.state.summaryBoxHidden;
  },

  expandSummaryBox() {
    this.state.expandSummaryBox = true;
    this.state.summaryBoxHidden = false;
  },

  regenerateSummary() {
    this.state.regenerate = true;
  },

  toggleSummaryBox() {
    this.state.summaryBoxHidden = !this.state.summaryBoxHidden;
  },
});
