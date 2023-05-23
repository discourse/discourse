import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
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

  get termMatch() {
    return this.search.activeGlobalSearchTerm?.match(MODIFIER_REGEXP)
      ? true
      : false;
  }

  constructor() {
    super(...arguments);

    const searchContext = this.search.searchContext;
    if (this.search.activeGlobalSearchTerm || searchContext) {
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
        this.topicContextType();
        break;
      case "private_messages":
        this.privateMessageContextType();
        break;
      case "category":
        this.categoryContextType();
        break;
      case "tag":
        this.tagContextType();
        break;
      case "tagIntersection":
        this.tagIntersectionContextType();
        break;
      case "user":
        this.userContextType();
        break;
    }
  }

  topicContextType() {
    this.slug = this.search.activeGlobalSearchTerm;
    this.setTopicContext = true;
    //this.label = [
    //h("span", `${this.search.activeGlobalSearchTerm} `),
    //h("span.label-suffix", I18n.t("search.in_this_topic")),
    //];
  }

  privateMessageContextType() {
    this.slug = `${this.search.activeGlobalSearchTerm} in:messages`;
  }

  categoryContextType() {
    const searchContextCategory = this.search.searchContext.category;
    const fullSlug = searchContextCategory.parentCategory
      ? `#${searchContextCategory.parentCategory.slug}:${searchContextCategory.slug}`
      : `#${searchContextCategory.slug}`;

    this.contextTypeSlug = `${this.search.activeGlobalSearchTerm} ${fullSlug}`;
    //THIS SHOULD NOT BE OVERRIDING THE TRACKED VAL
    //this.suggestionKeyword = "#";
    //THIS SHOULD NOT BE OVERRIDING THE TRACKED VAL
    //this.results = [{ model: this.search.searchContext.category }];
    this.withInLabel = true;
  }

  tagContextType() {
    this.contextTypeSlug = `${this.search.activeGlobalSearchTerm} #${this.search.searchContext.name}`;
    //THIS SHOULD NOT BE OVERRIDING THE TRACKED VAL
    //this.suggestionKeyword = "#";
    //THIS SHOULD NOT BE OVERRIDING THE TRACKED VAL
    //this.results = [{ name: this.search.searchContext.name }];
    this.withInLabel = true;
  }

  tagIntersectionContextType() {
    const searchContext = this.search.searchContext;

    let tagTerm;
    if (searchContext.additionalTags) {
      const tags = [searchContext.tagId, ...searchContext.additionalTags];
      tagTerm = `${this.search.activeGlobalSearchTerm} tags:${tags.join("+")}`;
    } else {
      tagTerm = `${this.search.activeGlobalSearchTerm} #${searchContext.tagId}`;
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

    this.contextTypeSlug = tagTerm;
    //THIS SHOULD NOT BE OVERRIDING THE TRACKED VAL
    //this.suggestionKeyword = "+";
    //THIS SHOULD NOT BE OVERRIDING THE TRACKED VAL
    //this.results = [suggestionOptions];
    this.withInLabel = true;
  }

  userContextType() {
    this.slug = `${this.search.activeGlobalSearchTerm} @${this.search.searchContext.user.username}`;
    //this.label = [
    //h("span", `${term} `),
    //h(
    //"span.label-suffix",
    //I18n.t("search.in_posts_by", {
    //username: this.search.searchContext.user.username,
    //})
    //),
    //];
  }
}
