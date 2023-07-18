import { createWidget } from "discourse/widgets/widget";
import hbs from "discourse/widgets/hbs-compiler";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { cookAsync } from "discourse/lib/text";
import RawHtml from "discourse/widgets/raw-html";
import I18n from "I18n";
import { shortDateNoYear } from "discourse/lib/formatter";
import { h } from "virtual-dom";

createWidget("summary-skeleton", {
  tagName: "section.placeholder-summary",
  template: hbs`
    <div class="placeholder-summary-text placeholder-animation"></div>
    <div class="placeholder-summary-text placeholder-animation"></div>
    <div class="placeholder-summary-text placeholder-animation"></div>
    <div class="placeholder-summary-text">{{transformed.in_progress_label}}</div>
  `,

  transform() {
    return { in_progress_label: I18n.t("summary.in_progress") };
  },
});

export default createWidget("summary-box", {
  tagName: "article.summary-box",
  buildKey: (attrs) => `summary-box-${attrs.topicId}`,

  defaultState() {
    return { expandSummarizedOn: false };
  },

  html(attrs, state) {
    const html = [];

    if (attrs.summary) {
      html.push(new RawHtml({ html: `<div>${attrs.summary}</div>` }));

      if (state.expandSummarizedOn) {
        html.push(
          h(
            "div.summarized-on",
            {},
            I18n.t("summary.summarized_on", {
              method: attrs.summarizedBy,
              date: attrs.summarizedOn,
            })
          )
        );
      } else {
        html.push(
          h("div.summarized-on", [
            this.attach("button", {
              className: "btn btn-link summarized-on",
              translatedTitle: I18n.t("summary.summarized_on", {
                method: "AI",
                date: attrs.summarizedOn,
              }),
              translatedLabel: I18n.t("summary.summarized_on", {
                method: "AI",
                date: attrs.summarizedOn,
              }),
              action: "showFullSummarizedOn",
            }),
          ])
        );
      }
    } else {
      html.push(this.attach("summary-skeleton"));
      this.fetchSummary(attrs.topicId);
    }

    return html;
  },

  showFullSummarizedOn() {
    this.state.expandSummarizedOn = true;
    this.scheduleRerender();
  },

  fetchSummary(topicId) {
    ajax(`/t/${topicId}/strategy-summary`)
      .then((data) => {
        cookAsync(data.summary).then((cooked) => {
          // We store the summary in the parent so we can re-render it without doing a new request.
          this.sendWidgetEvent("summaryUpdated", {
            summary: cooked.string,
            summarizedOn: shortDateNoYear(data.summarized_on),
            summarizedBy: data.summarized_by,
          });
        });
      })
      .catch(popupAjaxError);
  },
});
