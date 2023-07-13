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
    return { summary: "" };
  },

  html(attrs, state) {
    const html = [];

    if (state.summary) {
      html.push(new RawHtml({ html: `<div>${state.summary}</div>` }));
      html.push(
        h(
          "div.summarized-on",
          {},
          I18n.t("summary.summarized_on", { date: state.summarized_on })
        )
      );
    } else {
      html.push(this.attach("summary-skeleton"));
      this.fetchSummary(attrs.topicId);
    }

    return html;
  },

  fetchSummary(topicId) {
    ajax(`/t/${topicId}/strategy-summary`)
      .then((data) => {
        this.state.summarized_on = shortDateNoYear(data.summarized_on);

        cookAsync(data.summary).then((cooked) => {
          this.state.summary = cooked.string;
          this.scheduleRerender();
        });
      })
      .catch(popupAjaxError);
  },
});
