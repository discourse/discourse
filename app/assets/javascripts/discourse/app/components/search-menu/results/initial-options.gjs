import Component from "@glimmer/component";
import { service } from "@ember/service";
import { and, or } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import { MODIFIER_REGEXP } from "discourse/components/search-menu";
import AssistantItem from "discourse/components/search-menu/results/assistant-item";
import RandomQuickTip from "discourse/components/search-menu/results/random-quick-tip";
import RecentSearches from "discourse/components/search-menu/results/recent-searches";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import Assistant from "./assistant";

const SEARCH_CONTEXT_TYPE_COMPONENTS = {
  topic: AssistantItem,
  private_messages: AssistantItem,
  category: Assistant,
  tag: Assistant,
  tagIntersection: Assistant,
  user: AssistantItem,
};

const DISPLAY_INITIAL_OPTIONS_FOR_CONTEXT_TYPES = [
  "topic",
  "category",
  "tag",
  "tagIntersection",
  "user",
];

export default class InitialOptions extends Component {
  @service search;
  @service siteSettings;
  @service currentUser;

  constructor() {
    super(...arguments);

    if (this.search.activeGlobalSearchTerm || this.search.searchContext) {
      if (this.search.searchContext) {
        // set the component we will be using to display results
        this.contextTypeComponent =
          SEARCH_CONTEXT_TYPE_COMPONENTS[this.search.searchContext.type];
        // set attributes for the component
        this.setAttributesForSearchContextType(this.search.searchContext.type);
      }
    }
  }

  get termMatchesContextTypeKeyword() {
    return this.search.activeGlobalSearchTerm?.match(MODIFIER_REGEXP);
  }

  get displayInitialOptions() {
    if (this.search.activeGlobalSearchTerm) {
      return false;
    }
    return DISPLAY_INITIAL_OPTIONS_FOR_CONTEXT_TYPES.includes(
      this.search.searchContext?.type
    );
  }

  setAttributesForSearchContextType(type) {
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
    this.suffix = i18n("search.in_this_topic");
  }

  privateMessageContextType() {
    this.slug = "in:messages";
    this.label = "in:messages";
  }

  categoryContextType() {
    const searchContextCategory = this.search.searchContext.category;
    const fullSlug = searchContextCategory.parentCategory
      ? `#${searchContextCategory.parentCategory.slug}:${searchContextCategory.slug}`
      : `#${searchContextCategory.slug}`;

    this.slug = fullSlug;
    this.contextTypeKeyword = "#";
    this.initialResults = [{ model: this.search.searchContext.category }];
    this.withInLabel = true;
  }

  tagContextType() {
    this.slug = `#${this.search.searchContext.name}`;
    this.contextTypeKeyword = "#";
    this.initialResults = [{ name: this.search.searchContext.name }];
    this.withInLabel = true;
  }

  tagIntersectionContextType() {
    const searchContext = this.search.searchContext;

    let tagTerm;
    if (searchContext.additionalTags) {
      const tags = [searchContext.tagId, ...searchContext.additionalTags];
      tagTerm = `tags:${tags.join("+")}`;
    } else {
      tagTerm = `#${searchContext.tagId}`;
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

    this.slug = tagTerm;
    this.contextTypeKeyword = "+";
    this.initialResults = [suggestionOptions];
    this.withInLabel = true;
  }

  userContextType() {
    this.contextTypeKeyword = "@";
    this.slug = `@${this.search.searchContext.user.username}`;
    this.suffix = i18n("search.in_posts_by", {
      username: this.search.searchContext.user.username,
    });
  }

  <template>
    <ul class="search-menu-initial-options">
      <PluginOutlet
        @name="search-menu-initial-options"
        @outletArgs={{lazyHash
          termMatchesContextTypeKeyword=this.termMatchesContextTypeKeyword
          contextTypeComponent=this.contextTypeComponent
          slug=this.slug
          suggestionKeyword=this.contextTypeKeyword
          results=this.initialResults
          withInLabel=this.withInLabel
          suffix=this.suffix
          label=this.label
          closeSearchMenu=@closeSearchMenu
          searchTermChanged=@searchTermChanged
        }}
      >
        {{#if this.termMatchesContextTypeKeyword}}
          <AssistantItem
            @slug={{this.slug}}
            @extraHint={{true}}
            @closeSearchMenu={{@closeSearchMenu}}
            @searchTermChanged={{@searchTermChanged}}
            @suggestionKeyword={{this.contextTypeKeyword}}
          />
        {{else}}
          {{#if
            (or this.search.activeGlobalSearchTerm this.search.searchContext)
          }}
            {{#if this.search.activeGlobalSearchTerm}}
              <AssistantItem
                @suffix={{i18n "search.in_topics_posts"}}
                @closeSearchMenu={{@closeSearchMenu}}
                @searchAllTopics={{true}}
                @extraHint={{true}}
                @searchTermChanged={{@searchTermChanged}}
                @suggestionKeyword={{this.contextTypeKeyword}}
              />
            {{/if}}

            {{#if this.search.searchContext}}
              <this.contextTypeComponent
                @slug={{this.slug}}
                @suggestionKeyword={{this.contextTypeKeyword}}
                @results={{this.initialResults}}
                @withInLabel={{this.withInLabel}}
                @suffix={{this.suffix}}
                @label={{this.label}}
                @closeSearchMenu={{@closeSearchMenu}}
                @searchTermChanged={{@searchTermChanged}}
              />

              {{#if
                (and
                  this.currentUser
                  this.siteSettings.log_search_queries
                  this.displayInitialOptions
                )
              }}
                <RecentSearches
                  @closeSearchMenu={{@closeSearchMenu}}
                  @searchTermChanged={{@searchTermChanged}}
                />
              {{/if}}
            {{/if}}
          {{else}}
            <RandomQuickTip
              @searchInputId={{@searchInputId}}
              @searchTermChanged={{@searchTermChanged}}
            />
            {{#if (and this.currentUser this.siteSettings.log_search_queries)}}
              <RecentSearches
                @closeSearchMenu={{@closeSearchMenu}}
                @searchTermChanged={{@searchTermChanged}}
              />
            {{/if}}
          {{/if}}
        {{/if}}
      </PluginOutlet>
    </ul>
  </template>
}
