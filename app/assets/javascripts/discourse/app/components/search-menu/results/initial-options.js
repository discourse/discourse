import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import { MODIFIER_REGEXP } from "discourse/widgets/search-menu";
import AssistantItem from "./assistant-item";
import Assistant from "./assistant";

const SEARCH_CONTEXT_TYPE_COMPONENTS = {
  topic: AssistantItem,
  private_messages: AssistantItem,
  category: Assistant,
  tag: Assistant,
  tagIntersection: Assistant,
  user: AssistantItem,
};

export default class InitialOptions extends Component {
  @service search;
  @service siteSettings;
  @service currentUser;

  term = this.args.term || "";

  get termMatch() {
    return this.args.term?.match(MODIFIER_REGEXP) ? true : false;
  }

  constructor() {
    super(...arguments);

    const searchContext = this.search.searchContext;
    if (this.args.term || searchContext) {
      if (searchContext) {
        // set the component we will be using to display results
        this.contextTypeComponent =
          SEARCH_CONTEXT_TYPE_COMPONENTS[searchContext.type];
        // set attributes for the component
        this.attributesForSearchContextType(searchContext.type);
      }
    }
  }

  attributesForSearchContextType(type) {
    switch (type) {
      case "topic":
        return this.topicContextType();
      case "private_messages":
        return this.privateMessageContextType();
      case "category":
        return this.categoryContextType();
      case "tag":
        return this.tagContextType();
      case "tagIntersection":
        return this.tagIntersectionContextType();
      case "user":
        return this.userContextType();
    }
  }

  topicContextType() {
    this.slug = this.args.term;
    this.setTopicContext = true;
    this.label = [
      h("span", `${this.args.term} `),
      h("span.label-suffix", I18n.t("search.in_this_topic")),
    ];
  }

  privateMessageContextType() {
    this.slug = `${this.args.term} in:messages`;
  }

  categoryContextType() {
    const searchContextCategory = this.search.searchContext.category;
    const fullSlug = searchContextCategory.parentCategory
      ? `#${searchContextCategory.parentCategory.slug}:${searchContextCategory.slug}`
      : `#${searchContextCategory.slug}`;

    this.term = `${this.args.term} ${fullSlug}`;
    this.suggestionKeyword = "#";
    this.results = [{ model: this.search.searchContext.category }];
    this.withInLabel = true;
  }

  tagContextType() {
    this.term = `${this.args.term} #${this.search.searchContext.name}`;
    this.suggestionKeyword = "#";
    this.results = [{ name: this.search.searchContext.name }];
    this.withInLabel = true;
  }

  tagIntersectionContextType() {
    const searchContext = this.search.searchContext;

    let tagTerm;
    if (searchContext.additionalTags) {
      const tags = [searchContext.tagId, ...searchContext.additionalTags];
      tagTerm = `${this.args.term} tags:${tags.join("+")}`;
    } else {
      tagTerm = `${this.args.term} #${searchContext.tagId}`;
    }
    let suggestionOptions = {
      tagName: searchContext.tagId,
      additionalTags: searchContext.additionalTags,
    };
    if (searchContext.category) {
      const categorySlug = searchContext.category.parentCategory
        ? `#${searchContext.category.parentCategory.slug}:${searchContext.category.slug}`
        : `#${searchContext.category.slug}`;
      suggestionOptions.categoryName = categorySlug;
      suggestionOptions.category = searchContext.category;
      tagTerm = tagTerm + ` ${categorySlug}`;
    }

    this.term = tagTerm;
    this.suggestionKeyword = "+";
    this.results = [suggestionOptions];
    this.withInLabel = true;
  }

  userContextType() {
    this.slug = `${this.args.term} @${this.search.searchContext.user.username}`;
    this.label = [
      h("span", `${term} `),
      h(
        "span.label-suffix",
        I18n.t("search.in_posts_by", {
          username: this.search.searchContext.user.username,
        })
      ),
    ];
  }
}
