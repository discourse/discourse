import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import { MODIFIER_REGEXP } from "discourse/widgets/search-menu";

export default class InitialOptions extends Component {
  @service search;

  get termMatch() {
    return this.args.term?.match(MODIFIER_REGEXP) ? true : false;
  }

  constructor() {
    super(...arguments);

    const content = [];

    if (this.args.term || this.search.searchContext) {
      if (this.search.searchContext) {
        const term = this.args.term || "";
        switch (this.search.searchContext.type) {
          case "topic":
            content.push(
              this.attach("search-menu-assistant-item", {
                slug: term,
                setTopicContext: true,
                label: [
                  h("span", `${term} `),
                  h("span.label-suffix", I18n.t("search.in_this_topic")),
                ],
              })
            );
            break;

          case "private_messages":
            content.push(
              this.attach("search-menu-assistant-item", {
                slug: `${term} in:messages`,
              })
            );
            break;

          case "category":
            const fullSlug = this.search.searchContext.category.parentCategory
              ? `#${this.search.searchContext.category.parentCategory.slug}:${this.search.searchContext.category.slug}`
              : `#${this.search.searchContext.category.slug}`;

            content.push(
              this.attach("search-menu-assistant", {
                term: `${term} ${fullSlug}`,
                suggestionKeyword: "#",
                results: [{ model: this.search.searchContext.category }],
                withInLabel: true,
              })
            );

            break;
          case "tag":
            content.push(
              this.attach("search-menu-assistant", {
                term: `${term} #${this.search.searchContext.name}`,
                suggestionKeyword: "#",
                results: [{ name: this.search.searchContext.name }],
                withInLabel: true,
              })
            );
            break;
          case "tagIntersection":
            let tagTerm;
            if (this.search.searchContext.additionalTags) {
              const tags = [
                this.search.searchContext.tagId,
                ...this.search.searchContext.additionalTags,
              ];
              tagTerm = `${term} tags:${tags.join("+")}`;
            } else {
              tagTerm = `${term} #${this.search.searchContext.tagId}`;
            }
            let suggestionOptions = {
              tagName: this.search.searchContext.tagId,
              additionalTags: this.search.searchContext.additionalTags,
            };
            if (this.search.searchContext.category) {
              const categorySlug = this.search.searchContext.category
                .parentCategory
                ? `#${this.search.searchContext.category.parentCategory.slug}:${this.search.searchContext.category.slug}`
                : `#${this.search.searchContext.category.slug}`;
              suggestionOptions.categoryName = categorySlug;
              suggestionOptions.category = this.search.searchContext.category;
              tagTerm = tagTerm + ` ${categorySlug}`;
            }

            content.push(
              this.attach("search-menu-assistant", {
                term: tagTerm,
                suggestionKeyword: "+",
                results: [suggestionOptions],
                withInLabel: true,
              })
            );
            break;
          case "user":
            content.push(
              this.attach("search-menu-assistant-item", {
                slug: `${term} @${this.search.searchContext.user.username}`,
                label: [
                  h("span", `${term} `),
                  h(
                    "span.label-suffix",
                    I18n.t("search.in_posts_by", {
                      username: this.search.searchContext.user.username,
                    })
                  ),
                ],
              })
            );
            break;
        }
      }

      if (this.args.term) {
        content.push(this.defaultRow(this.args.term, { withLabel: true }));
      }
      return content;
    }

    if (content.length === 0) {
      content.push(this.attach("random-quick-tip"));

      if (this.currentUser && this.siteSettings.log_search_queries) {
        if (this.currentUser.recent_searches?.length) {
          content.push(this.attach("search-menu-recent-searches"));
        } else {
          this.loadRecentSearches();
        }
      }
    }

    return content;
  }

  defaultRow(term, opts = { withLabel: false }) {
    return this.attach("search-menu-assistant-item", {
      slug: term,
      extraHint: I18n.t("search.enter_hint"),
      label: [
        h("span.keyword", `${term}`),
        opts.withLabel
          ? h("span.label-suffix", I18n.t("search.in_topics_posts"))
          : null,
      ],
    });
  }

  refreshSearchMenuResults() {
    this.scheduleRerender();
  }

  loadRecentSearches() {
    User.loadRecentSearches().then((result) => {
      if (result.success && result.recent_searches?.length) {
        this.currentUser.set(
          "recent_searches",
          Object.assign(result.recent_searches)
        );
        this.scheduleRerender();
      }
    });
  }
}
