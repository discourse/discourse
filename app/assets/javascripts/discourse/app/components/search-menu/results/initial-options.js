import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import { MODIFIER_REGEXP } from "discourse/widgets/search-menu";

export default class InitialOptions extends Component {
  @service search;
  @service siteSettings;
  @service currentUser;

  slug;
  setTopicContext;
  setTopicContext;
  results;

  searchContextTypePicker(type) {
    switch (type) {
      case "topic":
        return this.topicContextType(type);
      case "private_messages":
        return this.privateMessageContextType(type);
      case "category":
        return this.categoryContextType(type);
      case "tag":
        return this.tagContextType(type);
      case "tagIntersection":
        return this.tagIntersectionContextType(type);
      case "user":
        return this.userContextType(type);
    }
  }

  get termMatch() {
    return this.args.term?.match(MODIFIER_REGEXP) ? true : false;
  }

  constructor() {
    super(...arguments);

    if (this.args.term || this.search.searchContext) {
      if (this.search.searchContext) {
        this.searchContextTypePicker(this.search.searchContext.type);
      }

      if (
        this.currentUser &&
        this.siteSettings.log_search_queries &&
        !this.currentUser.recent_searches?.length
      ) {
        this.loadRecentSearches();
      }
    }
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

  topicContextType(type) {
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
  }

  privateMessageContextType(type) {
    content.push(
      this.attach("search-menu-assistant-item", {
        slug: `${term} in:messages`,
      })
    );
  }

  categoryContextType(type) {
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
  }

  tagContextType(type) {
    content.push(
      this.attach("search-menu-assistant", {
        term: `${term} #${this.search.searchContext.name}`,
        suggestionKeyword: "#",
        results: [{ name: this.search.searchContext.name }],
        withInLabel: true,
      })
    );
  }

  tagIntersectionContextType(type) {
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
      const categorySlug = this.search.searchContext.category.parentCategory
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
  }

  userContextType(type) {
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
  }
}
