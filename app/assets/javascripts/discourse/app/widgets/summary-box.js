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

    const summary = attrs.summary;

    if (summary && !attrs.skipAgeCheck) {
      html.push(
        new RawHtml({
          html: `<div class="generated-summary">${summary.summarized_text}</div>`,
        })
      );

      const summarizationInfo = [
        h("p", {}, [
          I18n.t("summary.summarized_on", { date: summary.summarized_on }),
          this.buildTooltip(attrs),
        ]),
      ];

      if (summary.outdated) {
        summarizationInfo.push(this.outdatedSummaryWarning(attrs));
      }

      html.push(h("div.summarized-on", {}, summarizationInfo));
    } else {
      html.push(this.attach("summary-skeleton"));
      this.fetchSummary(attrs.topicId, attrs.skipAgeCheck);
    }

    return html;
  },

  buildTooltip(attrs) {
    return new RenderGlimmer(
      this,
      "span",
      hbs`{{d-icon "info-circle"}}<DTooltip @placement="top-end">
        {{i18n "summary.model_used" model=@data.summarizedBy}}
      </DTooltip>`,
      {
        summarizedBy: attrs.summary.summarized_by,
      }
    );
  },

  outdatedSummaryWarning(attrs) {
    let outdatedText = I18n.t("summary.outdated");

    if (
      !attrs.hasTopRepliesSummary &&
      attrs.summary.new_posts_since_summary > 0
    ) {
      outdatedText += " ";
      outdatedText += I18n.t("summary.outdated_posts", {
        count: attrs.summary.new_posts_since_summary,
      });
    }

    return h("p.outdated-summary", {}, [
      outdatedText,
      iconNode("exclamation-triangle", { class: "info-icon" }),
    ]);
  },

  fetchSummary(topicId, skipAgeCheck) {
    let fetchURL = `/t/${topicId}/strategy-summary`;

    if (skipAgeCheck) {
      fetchURL += "?skip_age_check=true";
    }

    ajax(fetchURL)
      .then((data) => {
        cookAsync(data.summary).then((cooked) => {
          // We store the summary in the parent so we can re-render it without doing a new request.
          data.summarized_text = cooked.string;
          data.summarized_on = shortDateNoYear(data.summarized_on);

          if (skipAgeCheck) {
            data.regenerated = true;
          }

          this.sendWidgetEvent("summaryUpdated", data);
        });
      })
      .catch(popupAjaxError);
  },
});
