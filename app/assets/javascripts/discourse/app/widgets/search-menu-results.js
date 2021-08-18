import { escapeExpression, formatUsername } from "discourse/lib/utilities";
import I18n from "I18n";
import RawHtml from "discourse/widgets/raw-html";
import { avatarImg } from "discourse/widgets/post";
import { createWidget } from "discourse/widgets/widget";
import { dateNode } from "discourse/helpers/node";
import { emojiUnescape } from "discourse/lib/text";
import getURL from "discourse-common/lib/get-url";
import { h } from "virtual-dom";
import highlightSearch from "discourse/lib/highlight-search";
import { iconNode } from "discourse-common/lib/icon-library";
import renderTag from "discourse/lib/render-tag";

const suggestionShortcuts = [
  "in:title",
  "in:pinned",
  "status:open",
  "status:closed",
  "status:public",
  "status:noreplies",
  "order:latest",
  "order:views",
  "order:likes",
  "order:latest_topic",
];

export function addSearchSuggestion(value) {
  if (suggestionShortcuts.indexOf(value) === -1) {
    suggestionShortcuts.push(value);
  }
}

class Highlighted extends RawHtml {
  constructor(html, term) {
    super({ html: `<span>${html}</span>` });
    this.term = term;
  }

  decorate($html) {
    highlightSearch($html[0], this.term);
  }
}

function createSearchResult({ type, linkField, builder }) {
  return createWidget(`search-result-${type}`, {
    tagName: "ul.list",

    html(attrs) {
      return attrs.results.map((r) => {
        let searchResultId;

        if (type === "topic") {
          searchResultId = r.topic_id;
        } else {
          searchResultId = r.id;
        }

        return h(
          "li.item",
          this.attach("link", {
            href: r[linkField],
            contents: () => builder.call(this, r, attrs.term),
            className: "search-link",
            searchResultId,
            searchResultType: type,
            searchContextEnabled: attrs.searchContextEnabled,
            searchLogId: attrs.searchLogId,
          })
        );
      });
    },
  });
}

function postResult(result, link, term) {
  const html = [link];

  if (!this.site.mobileView) {
    html.push(
      h("span.blurb", [
        dateNode(result.created_at),
        h("span", " - "),
        this.siteSettings.use_pg_headlines_for_excerpt
          ? new RawHtml({ html: `<span>${result.blurb}</span>` })
          : new Highlighted(result.blurb, term),
      ])
    );
  }

  return html;
}

createSearchResult({
  type: "tag",
  linkField: "url",
  builder(t) {
    const tag = escapeExpression(t.id);
    return new RawHtml({ html: renderTag(tag, { tagName: "span" }) });
  },
});

createSearchResult({
  type: "category",
  linkField: "url",
  builder(c) {
    return this.attach("category-link", { category: c, link: false });
  },
});

createSearchResult({
  type: "group",
  linkField: "url",
  builder(group) {
    const fullName = escapeExpression(group.fullName);
    const name = escapeExpression(group.name);
    const groupNames = [h("span.name", fullName || name)];

    if (fullName) {
      groupNames.push(h("span.slug", name));
    }

    let avatarFlair;
    if (group.flairUrl) {
      avatarFlair = this.attach("avatar-flair", {
        flair_name: name,
        flair_url: group.flairUrl,
        flair_bg_color: group.flairBgColor,
        flair_color: group.flairColor,
      });
    } else {
      avatarFlair = iconNode("users");
    }

    const groupResultContents = [avatarFlair, h("div.group-names", groupNames)];

    return h("div.group-result", groupResultContents);
  },
});

createSearchResult({
  type: "user",
  linkField: "path",
  builder(u) {
    const userTitles = [];

    if (u.name) {
      userTitles.push(h("span.name", u.name));
    }

    userTitles.push(h("span.username", formatUsername(u.username)));

    if (u.custom_data) {
      u.custom_data.forEach((row) =>
        userTitles.push(h("span.custom-field", `${row.name}: ${row.value}`))
      );
    }

    const userResultContents = [
      avatarImg("small", {
        template: u.avatar_template,
        username: u.username,
      }),
      h("div.user-titles", userTitles),
    ];

    return h("div.user-result", userResultContents);
  },
});

createSearchResult({
  type: "topic",
  linkField: "url",
  builder(result, term) {
    const topic = result.topic;

    const firstLine = [
      this.attach("topic-status", { topic, disableActions: true }),
      h(
        "span.topic-title",
        { attributes: { "data-topic-id": topic.id } },
        this.siteSettings.use_pg_headlines_for_excerpt &&
          result.topic_title_headline
          ? new RawHtml({
              html: `<span>${emojiUnescape(
                result.topic_title_headline
              )}</span>`,
            })
          : new Highlighted(topic.fancyTitle, term)
      ),
    ];

    const secondLine = [
      this.attach("category-link", {
        category: topic.category,
        link: false,
      }),
    ];
    if (this.siteSettings.tagging_enabled) {
      secondLine.push(
        this.attach("discourse-tags", { topic, tagName: "span" })
      );
    }

    const link = h("span.topic", [
      h("span.first-line", firstLine),
      h("span.second-line", secondLine),
    ]);

    return postResult.call(this, result, link, term);
  },
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
  },
});

createWidget("search-menu-results", {
  tagName: "div.results",

  html(attrs) {
    if (attrs.suggestionKeyword) {
      return this.attach("search-menu-assistant", {
        fullTerm: attrs.term,
        suggestionKeyword: attrs.suggestionKeyword,
        results: attrs.suggestionResults || [],
      });
    }

    if (attrs.invalidTerm) {
      return h("div.no-results", I18n.t("search.too_short"));
    }

    if (attrs.noResults) {
      return h("div.no-results", I18n.t("search.no_results"));
    }

    const results = attrs.results;
    const resultTypes = results.resultTypes || [];

    const mainResultsContent = [];
    const usersAndGroups = [];
    const categoriesAndTags = [];
    const usersAndGroupsMore = [];
    const categoriesAndTagsMore = [];

    const buildMoreNode = (result) => {
      const more = [];

      const moreArgs = {
        className: "filter",
        contents: () => [I18n.t("more"), "..."],
      };

      if (result.moreUrl) {
        more.push(
          this.attach("link", $.extend(moreArgs, { href: result.moreUrl }))
        );
      } else if (result.more) {
        more.push(
          this.attach(
            "link",
            $.extend(moreArgs, {
              action: "moreOfType",
              actionParam: result.type,
              className: "filter filter-type",
            })
          )
        );
      }

      if (more.length) {
        return more;
      }
    };

    const assignContainer = (result, node) => {
      if (["topic"].includes(result.type)) {
        mainResultsContent.push(node);
      }

      if (["user", "group"].includes(result.type)) {
        usersAndGroups.push(node);
        usersAndGroupsMore.push(buildMoreNode(result));
      }

      if (["category", "tag"].includes(result.type)) {
        categoriesAndTags.push(node);
        categoriesAndTagsMore.push(buildMoreNode(result));
      }
    };

    resultTypes.forEach((rt) => {
      const resultNodeContents = [
        this.attach(rt.componentName, {
          searchContextEnabled: attrs.searchContextEnabled,
          searchLogId: attrs.results.grouped_search_result.search_log_id,
          results: rt.results,
          term: attrs.term,
        }),
      ];

      if (["topic"].includes(rt.type)) {
        const more = buildMoreNode(rt);
        if (more) {
          resultNodeContents.push(h("div.show-more", more));
        }
      }

      assignContainer(rt, h(`div.${rt.componentName}`, resultNodeContents));
    });

    const content = [];

    if (mainResultsContent.length) {
      content.push(h("div.main-results", mainResultsContent));
    }

    if (usersAndGroups.length || categoriesAndTags.length) {
      const secondaryResultsContents = [];

      secondaryResultsContents.push(usersAndGroups);
      secondaryResultsContents.push(usersAndGroupsMore);

      if (usersAndGroups.length && categoriesAndTags.length) {
        secondaryResultsContents.push(h("div.separator"));
      }

      secondaryResultsContents.push(categoriesAndTags);
      secondaryResultsContents.push(categoriesAndTagsMore);

      const secondaryResults = h(
        "div.secondary-results",
        secondaryResultsContents
      );

      content.push(secondaryResults);
    }

    return content;
  },
});

createWidget("search-menu-assistant", {
  tagName: "ul.search-menu-assistant",

  html(attrs) {
    if (this.currentUser) {
      addSearchSuggestion("in:likes");
      addSearchSuggestion("in:bookmarks");
      addSearchSuggestion("in:mine");
      addSearchSuggestion("in:personal");
      addSearchSuggestion("in:seen");
      addSearchSuggestion("in:tracking");
      addSearchSuggestion("in:unseen");
      addSearchSuggestion("in:watching");
    }
    if (this.siteSettings.tagging_enabled) {
      addSearchSuggestion("in:tagged");
      addSearchSuggestion("in:untagged");
    }

    const content = [];
    const { fullTerm, suggestionKeyword } = attrs;
    let prefix = fullTerm.split(suggestionKeyword)[0].trim() || "";

    if (prefix.length) {
      prefix = `${prefix} `;
    }

    switch (suggestionKeyword) {
      case "#":
        attrs.results.forEach((item) => {
          if (item.model) {
            const fullSlug = item.model.parentCategory
              ? `#${item.model.parentCategory.slug}:${item.model.slug}`
              : `#${item.model.slug}`;

            content.push(
              this.attach("search-menu-assistant-item", {
                prefix,
                category: item.model,
                slug: `${prefix}${fullSlug} `,
              })
            );
          } else {
            content.push(
              this.attach("search-menu-assistant-item", {
                prefix,
                tag: item.name,
                slug: `${prefix}#${item.name} `,
              })
            );
          }
        });
        break;
      case "@":
        attrs.results.forEach((user) => {
          content.push(
            this.attach("search-menu-assistant-item", {
              prefix,
              user,
              slug: `${prefix}@${user.username} `,
            })
          );
        });
        break;
      default:
        suggestionShortcuts.forEach((item) => {
          if (item.includes(suggestionKeyword)) {
            content.push(
              this.attach("search-menu-assistant-item", {
                slug: `${prefix}${item} `,
              })
            );
          }
        });
        break;
    }

    return content.filter((c, i) => i <= 8);
  },
});

createWidget("search-menu-assistant-item", {
  tagName: "li.search-menu-assistant-item",

  html(attrs) {
    const prefix = attrs.prefix?.trim();
    if (attrs.category) {
      return h(
        "a.widget-link.search-link",
        {
          attributes: {
            href: attrs.category.url,
          },
        },
        [
          h("span.search-item-prefix", prefix),
          this.attach("category-link", {
            category: attrs.category,
            allowUncategorized: true,
            recursive: true,
          }),
        ]
      );
    } else if (attrs.tag) {
      return h(
        "a.widget-link.search-link",
        {
          attributes: {
            href: getURL(`/tag/${attrs.tag}`),
          },
        },
        [
          h("span.search-item-prefix", prefix),
          iconNode("tag"),
          h("span.search-item-tag", attrs.tag),
        ]
      );
    } else if (attrs.user) {
      const userResult = [
        avatarImg("small", {
          template: attrs.user.avatar_template,
          username: attrs.user.username,
        }),
        h("span.username", formatUsername(attrs.user.username)),
      ];

      return h(
        "a.widget-link.search-link",
        {
          attributes: {
            href: "#",
          },
        },
        [
          h("span.search-item-prefix", prefix),
          h("span.search-item-user", userResult),
        ]
      );
    } else {
      return h(
        "a.widget-link.search-link",
        {
          attributes: {
            href: "#",
          },
        },
        h("span.search-item-slug", attrs.slug)
      );
    }
  },

  click(e) {
    const searchInput = document.querySelector("#search-term");
    searchInput.value = this.attrs.slug;
    searchInput.focus();
    this.sendWidgetAction("triggerAutocomplete", this.attrs.slug);
    e.preventDefault();
    return false;
  },
});
