import { avatarImg } from "discourse/widgets/post";
import { dateNode } from "discourse/helpers/node";
import RawHtml from "discourse/widgets/raw-html";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import highlightText from "discourse/lib/highlight-text";
import { escapeExpression, formatUsername } from "discourse/lib/utilities";

class Highlighted extends RawHtml {
  constructor(html, term) {
    super({ html: `<span>${html}</span>` });
    this.term = term;
  }

  decorate($html) {
    highlightText($html, this.term);
  }
}

function createSearchResult({ type, linkField, builder }) {
  return createWidget(`search-result-${type}`, {
    tagName: "ul.list",

    html(attrs) {
      return attrs.results.map(r => {
        let searchResultId;

        if (type === "topic") {
          searchResultId = r.get("topic_id");
        } else {
          searchResultId = r.get("id");
        }

        return h(
          "li.item",
          this.attach("link", {
            href: r.get(linkField),
            contents: () => builder.call(this, r, attrs.term),
            className: "search-link",
            searchResultId,
            searchResultType: type,
            searchContextEnabled: attrs.searchContextEnabled,
            searchLogId: attrs.searchLogId
          })
        );
      });
    }
  });
}

function postResult(result, link, term) {
  const html = [link];

  if (!this.site.mobileView) {
    html.push(
      h("span.blurb", [
        dateNode(result.created_at),
        h("span", " - "),
        new Highlighted(result.blurb, term)
      ])
    );
  }

  return html;
}

createSearchResult({
  type: "tag",
  linkField: "url",
  builder(t) {
    const tag = escapeExpression(t.get("id"));
    return h(
      "a",
      {
        attributes: { href: t.get("url") },
        className: `widget-link search-link tag-${tag} discourse-tag ${
          Discourse.SiteSettings.tag_style
        }`
      },
      tag
    );
  }
});

createSearchResult({
  type: "category",
  linkField: "url",
  builder(c) {
    return this.attach("category-link", { category: c, link: false });
  }
});

createSearchResult({
  type: "user",
  linkField: "path",
  builder(u) {
    const userTitles = [h("span.username", formatUsername(u.username))];

    if (u.name) {
      userTitles.push(h("span.name", u.name));
    }

    const userResultContents = [
      avatarImg("small", {
        template: u.avatar_template,
        username: u.username
      }),
      h("div.user-titles", userTitles)
    ];

    return h("div.user-result", userResultContents);
  }
});

createSearchResult({
  type: "topic",
  linkField: "url",
  builder(result, term) {
    const topic = result.topic;
    const link = h("span.topic", [
      this.attach("topic-status", { topic, disableActions: true }),
      h("span.topic-title", new Highlighted(topic.get("fancyTitle"), term)),
      this.attach("category-link", {
        category: topic.get("category"),
        link: false
      })
    ]);

    return postResult.call(this, result, link, term);
  }
});

createSearchResult({
  type: "post",
  linkField: "url",
  builder(result, term) {
    return postResult.call(
      this,
      result,
      I18n.t("search.post_format", result),
      term
    );
  }
});

createWidget("search-menu-results", {
  tagName: "div.results",

  html(attrs) {
    if (attrs.invalidTerm) {
      return h("div.no-results", I18n.t("search.too_short"));
    }

    if (attrs.noResults) {
      return h("div.no-results", I18n.t("search.no_results"));
    }

    const results = attrs.results;
    const resultTypes = results.resultTypes || [];

    const mainResultsContent = [];
    const classificationContents = [];
    const otherContents = [];
    const assignContainer = (type, node) => {
      if (["topic"].includes(type)) {
        mainResultsContent.push(node);
      } else if (["category", "tag"].includes(type)) {
        classificationContents.push(node);
      } else {
        otherContents.push(node);
      }
    };

    resultTypes.forEach(rt => {
      const more = [];

      const moreArgs = {
        className: "filter",
        contents: () => [I18n.t("more"), "..."]
      };

      if (rt.moreUrl) {
        more.push(
          this.attach("link", $.extend(moreArgs, { href: rt.moreUrl }))
        );
      } else if (rt.more) {
        more.push(
          this.attach(
            "link",
            $.extend(moreArgs, {
              action: "moreOfType",
              actionParam: rt.type,
              className: "filter filter-type"
            })
          )
        );
      }

      const resultNodeContents = [
        this.attach(rt.componentName, {
          searchContextEnabled: attrs.searchContextEnabled,
          searchLogId: attrs.results.grouped_search_result.search_log_id,
          results: rt.results,
          term: attrs.term
        })
      ];

      if (more.length) {
        resultNodeContents.push(h("div.show-more", more));
      }

      assignContainer(
        rt.type,
        h(`div.${rt.componentName}`, resultNodeContents)
      );
    });

    const content = [];

    if (mainResultsContent.length) {
      content.push(h("div.main-results", mainResultsContent));
    }

    if (classificationContents.length || otherContents.length) {
      const secondaryResultsContent = [];

      if (classificationContents.length) {
        secondaryResultsContent.push(
          h("div.classification-results", classificationContents)
        );
      }

      if (otherContents.length) {
        secondaryResultsContent.push(h("div.other-results", otherContents));
      }

      content.push(
        h(
          `div.secondary-results${
            mainResultsContent.length ? "" : ".no-main-results"
          }`,
          secondaryResultsContent
        )
      );
    }

    return content;
  }
});
