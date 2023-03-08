import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";

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
  "+": "tag",
  "#": "category",
  "@": "user",
};

export default class Assistant extends Component {
  @service router;
  @service currentUser;
  @service siteSettings;

  suggestionType;
  prefix;
  //  we need access to the shorcuts in the view
  suggestionShortcuts = suggestionShortcuts;

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

    this.attributesForSuggestionKeyword();
  }

  get userMatchesInTopic() {
    return (
      this.args.results.length === 1 &&
      this.router.currentRouteName.startsWith("topic.")
    );
  }

  isSuggestionKeyword(item) {
    debugger;
    return (
      item.includes(this.args.suggestionKeyword) || !this.args.suggestionKeyword
    );
  }

  attributesForSuggestionKeyword() {
    if (this.args.suggestionKeyword !== "+") {
      this.prefix =
        this.args.term?.split(this.args.suggestionKeyword)[0].trim() || "";
      if (this.prefix.length) {
        this.prefix = `${this.prefix} `;
      }
    }

    console.log(this.args.suggestionKeyword);
    switch (this.args.suggestionKeyword) {
      case "+":
        this.args.results.forEach((result) => {
          if (result.additionalTags) {
            this.prefix =
              this.args.term?.split(" ").slice(0, -1).join(" ").trim() || "";
          } else {
            this.prefix = this.args.term?.split("#")[0].trim() || "";
          }
          if (this.prefix.length) {
            this.prefix = `${this.prefix} `;
          }
        });

        this.suggestionType =
          SUGGESTION_KEYWORD_MAP[this.args.suggestionKeyword];
        break;
      case "#":
        // For all results that are a category we need to assign
        // a 'fullSlug' for each object. It would place too much logic
        // to do this on the fly within the view so instead we build
        // a 'fullSlugForCategoryMap' which we can then
        // access in the view by 'category.id'
        this.fullSlugForCategoryMap = {};
        this.args.results.forEach((result) => {
          if (result.model) {
            const fullSlug = result.model.parentCategory
              ? `#${result.model.parentCategory.slug}:${result.model.slug}`
              : `#${result.model.slug}`;
            this.fullSlugForCategoryMap[
              result.model.id
            ] = `${this.prefix}${fullSlug}`;
          }
        });

        this.suggestionType =
          SUGGESTION_KEYWORD_MAP[this.args.suggestionKeyword];
        break;
      case "@":
        // when only one user matches while in topic
        // quick suggest user search in the topic or globally
        if (this.userMatchesInTopic) {
          this.user = this.args.results[0];
        }

        this.suggestionType =
          SUGGESTION_KEYWORD_MAP[this.args.suggestionKeyword];
        break;
    }
    // SOMEHOW WE NEED TO ONLY RENDER 8 OPTIONS
    //return content.filter((c, i) => i <= 8);
  }
}

export function addSearchSuggestion(value) {
  if (!suggestionShortcuts.includes(value)) {
    suggestionShortcuts.push(value);
  }
}
