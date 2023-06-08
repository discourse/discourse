import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

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

const SUGGESTION_KEYWORD_MAP = {
  "+": "tagIntersection",
  "#": "categoryOrTag",
  "@": "user",
};

export default class Assistant extends Component {
  @service router;
  @service currentUser;
  @service siteSettings;
  @service search;

  constructor() {
    super(...arguments);

    if (this.currentUser) {
      addSearchSuggestion("in:likes");
      addSearchSuggestion("in:bookmarks");
      addSearchSuggestion("in:mine");
      addSearchSuggestion("in:messages");
      addSearchSuggestion("in:seen");
      addSearchSuggestion("in:tracking");
      addSearchSuggestion("in:unseen");
      addSearchSuggestion("in:watching");
    }

    if (this.siteSettings.tagging_enabled) {
      addSearchSuggestion("in:tagged");
      addSearchSuggestion("in:untagged");
    }
  }

  get suggestionShortcuts() {
    const shortcut = this.search.activeGlobalSearchTerm.split(" ").slice(-1);
    const suggestions = suggestionShortcuts.filter((suggestion) =>
      suggestion.includes(shortcut)
    );
    return suggestions.slice(0, 8);
  }

  get userMatchesInTopic() {
    return (
      this.args.results.length === 1 &&
      this.router.currentRouteName.startsWith("topic.")
    );
  }

  get suggestionType() {
    switch (this.args.suggestionKeyword) {
      case "+":
        return SUGGESTION_KEYWORD_MAP[this.args.suggestionKeyword];
      case "#":
        return SUGGESTION_KEYWORD_MAP[this.args.suggestionKeyword];
      case "@":
        return SUGGESTION_KEYWORD_MAP[this.args.suggestionKeyword];
    }
  }

  get prefix() {
    let prefix = "";
    if (this.args.suggestionKeyword !== "+") {
      prefix =
        this.args.slug?.split(this.args.suggestionKeyword)[0].trim() || "";
      if (prefix.length) {
        prefix = `${prefix} `;
      }
    } else {
      this.args.results.forEach((result) => {
        if (result.additionalTags) {
          prefix =
            this.args.slug?.split(" ").slice(0, -1).join(" ").trim() || "";
        } else {
          prefix = this.args.slug?.split("#")[0].trim() || "";
        }
        if (prefix.length) {
          prefix = `${prefix} `;
        }
      });
    }
    return prefix;
  }

  // For all results that are a category we need to assign
  // a 'fullSlug' for each object. It would place too much logic
  // to do this on the fly within the view so instead we build
  // a 'fullSlugForCategoryMap' which we can then
  // access in the view by 'category.id'
  get fullSlugForCategoryMap() {
    const categoryMap = {};
    this.args.results.forEach((result) => {
      if (result.model) {
        const fullSlug = result.model.parentCategory
          ? `#${result.model.parentCategory.slug}:${result.model.slug}`
          : `#${result.model.slug}`;
        categoryMap[result.model.id] = `${this.prefix}${fullSlug}`;
      }
    });
    return categoryMap;
  }

  get user() {
    // when only one user matches while in topic
    // quick suggest user search in the topic or globally
    return this.args.results[0];
  }
}

export function addSearchSuggestion(value) {
  if (!suggestionShortcuts.includes(value)) {
    suggestionShortcuts.push(value);
  }
}
