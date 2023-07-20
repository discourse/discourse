import { createWidget } from "discourse/widgets/widget";
import { hbs } from "ember-cli-htmlbars";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { cookAsync } from "discourse/lib/text";
import RawHtml from "discourse/widgets/raw-html";
import I18n from "I18n";
import { shortDateNoYear } from "discourse/lib/formatter";
import { h } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";
import RenderGlimmer from "discourse/widgets/render-glimmer";

createWidget("summary-skeleton", {
  tagName: "section.placeholder-summary",

  html() {
    const html = [];

    html.push(this.buildPlaceholderDiv());
    html.push(this.buildPlaceholderDiv());
    html.push(this.buildPlaceholderDiv());

    html.push(
      h("span", {}, [
        iconNode("magic", { class: "rotate-center" }),
        h(
          "div.placeholder-generating-summary-text",
          {},
          I18n.t("summary.in_progress")
        ),
      ])
    );

    return html;
  },

  buildPlaceholderDiv() {
    return h("div.placeholder-summary-text.placeholder-animation");
  },
});

export default createWidget("summary-box", {
  tagName: "article.summary-box",
  buildKey: (attrs) => `summary-box-${attrs.topicId}`,

  defaultState() {
    return { expandSummarizedOn: false };
  },

  html(attrs) {
    const html = [];

    if (attrs.summary) {
      html.push(
        new RawHtml({
          html: `<div class="generated-summary">${attrs.summary}</div>`,
        })
      );
      html.push(
        h("div.summarized-on", {}, [
          new RenderGlimmer(
            this,
            "div",
            hbs`{{@data.summarizedOn}}
            {{d-icon "info-circle"}}
            <DTooltip @placement="top-end">
              {{i18n "summary.model_used" model=@data.attrs.summarizedBy}}
            </DTooltip>`,
            {
              attrs,
              summarizedOn: I18n.t("summary.summarized_on", {
                date: attrs.summarizedOn,
              }),
            }
          ),
        ])
      );
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
