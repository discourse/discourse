/* eslint-disable ember/no-classic-components */
import { tracked } from "@glimmer/tracking";
import Component, { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import ComboBox from "discourse/select-kit/components/combo-box";
import MultiSelect from "discourse/select-kit/components/multi-select";
import SearchAdvancedCategoryChooser from "discourse/select-kit/components/search-advanced-category-chooser";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import UserChooser from "discourse/select-kit/components/user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DDateInput from "discourse/ui-kit/d-date-input";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const REGEXP_BLOCKS = /(([^" \t\n\x0B\f\r]+)?(("[^"]+")?))/g;

const REGEXP_USERNAME_PREFIX = /^(user:|@)/gi;
const REGEXP_CATEGORY_PREFIX = /^(category:|#)/gi;
const REGEXP_TAGS_PREFIX = /^(tags?:|#(?=[a-z0-9\-]+::tag))/gi;
const REGEXP_IN_PREFIX = /^(in|with):/gi;
const REGEXP_STATUS_PREFIX = /^status:/gi;
const REGEXP_MIN_POSTS_PREFIX = /^min_posts:/gi;
const REGEXP_MAX_POSTS_PREFIX = /^max_posts:/gi;
const REGEXP_MIN_VIEWS_PREFIX = /^min_views:/gi;
const REGEXP_MAX_VIEWS_PREFIX = /^max_views:/gi;
const REGEXP_POST_TIME_PREFIX = /^(before|after):/gi;
const REGEXP_TAGS_REPLACE = /(^(tags?:|#(?=[a-z0-9\-]+::tag))|::tag\s?$)/gi;

const REGEXP_CATEGORY_SLUG = /^(\#[a-zA-Z0-9\-:]+)/gi;
const REGEXP_CATEGORY_ID = /^(category:[0-9]+)/gi;
const REGEXP_POST_TIME_WHEN = /^(before|after)/gi;

const IN_OPTIONS_MAPPING = { images: "with" };

let _extraOptions = [];

function buildFilterOptions(keys, extraOptionsKey) {
  return keys
    .map((key) => ({
      name: i18n(`search.advanced.filters.${key}`),
      value: key === "private" ? "messages" : key,
    }))
    .concat(..._extraOptions.map((eo) => eo[extraOptionsKey]).filter(Boolean));
}

function inOptionsForUsers() {
  return buildFilterOptions(
    [
      // User actions
      "created",
      "posted",
      "likes",
      "bookmarks",
      // Read state
      "seen",
      "unseen",
      // Subscriptions
      "watching",
      "tracking",
      // Messages
      "all",
      "private",
    ],
    "inOptionsForUsers"
  );
}

function inOptionsForAll() {
  return buildFilterOptions(
    [
      // Post properties
      "first",
      "pinned",
      "wiki",
      "images",
      // Search scope
      "title",
    ],
    "inOptionsForAll"
  );
}

function statusOptions() {
  return [
    { name: i18n("search.advanced.statuses.open"), value: "open" },
    { name: i18n("search.advanced.statuses.closed"), value: "closed" },
    { name: i18n("search.advanced.statuses.public"), value: "public" },
    { name: i18n("search.advanced.statuses.archived"), value: "archived" },
    {
      name: i18n("search.advanced.statuses.noreplies"),
      value: "noreplies",
    },
    {
      name: i18n("search.advanced.statuses.single_user"),
      value: "single_user",
    },
  ].concat(..._extraOptions.map((eo) => eo.statusOptions).filter(Boolean));
}

function postTimeOptions() {
  return [
    { name: i18n("search.advanced.post.time.before"), value: "before" },
    { name: i18n("search.advanced.post.time.after"), value: "after" },
  ].concat(..._extraOptions.map((eo) => eo.postTimeOptions).filter(Boolean));
}

export function addAdvancedSearchOptions(options) {
  _extraOptions.push(options);
}

@tagName("")
export default class SearchAdvancedOptions extends Component {
  @service appEvents;

  @tracked isExpanded = false;
  @tracked submittedFilterCount = 0;
  category = null;

  init() {
    super.init(...arguments);

    this.isExpanded = this.expandFilters || false;
    this._lastExpandFilters = this.expandFilters;
    this.appEvents.on(
      "full-page-search:collapse-filters",
      this,
      this._collapseFilters
    );

    this.setProperties({
      searchedTerms: {
        username: null,
        category: null,
        tags: null,
        in: [],
        special: {
          all_tags: false,
        },
        status: null,
        min_posts: null,
        max_posts: null,
        min_views: null,
        max_views: null,
        time: {
          when: "before",
          days: null,
        },
      },
      inOptions: this.currentUser
        ? inOptionsForUsers().concat(inOptionsForAll())
        : inOptionsForAll(),
      statusOptions: statusOptions(),
      postTimeOptions: postTimeOptions(),
      showAllTagsCheckbox: false,
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      "full-page-search:collapse-filters",
      this,
      this._collapseFilters
    );
  }

  @computed(
    "searchedTerms.username",
    "searchedTerms.category.id",
    "searchedTerms.tags.[]",
    "searchedTerms.in.[]",
    "searchedTerms.special.all_tags",
    "searchedTerms.status",
    "searchedTerms.min_posts",
    "searchedTerms.max_posts",
    "searchedTerms.min_views",
    "searchedTerms.max_views",
    "searchedTerms.time.days"
  )
  get activeFilterCount() {
    const t = this.searchedTerms;
    if (!t) {
      return 0;
    }
    return [
      t.username,
      t.category?.id,
      t.tags?.length,
      t.in?.length,
      t.special?.all_tags,
      t.status,
      t.min_posts,
      t.max_posts,
      t.min_views,
      t.max_views,
      t.time?.days,
    ].filter(Boolean).length;
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    if (this.expandFilters !== this._lastExpandFilters) {
      this._lastExpandFilters = this.expandFilters;
      this.isExpanded = this.expandFilters || false;
    }

    this.setSearchedTermValue("searchedTerms.username", REGEXP_USERNAME_PREFIX);
    this.setSearchedTermValueForCategory();
    this.setSearchedTermValueForTags();
    this.setSearchedTermValueForIn();

    let regExpStatusMatch = this.statusOptions
      .map((status) => status.value)
      .join("|");
    const REGEXP_STATUS_MATCH = new RegExp(
      `status:(${regExpStatusMatch})`,
      "i"
    );

    this.setSearchedTermValue(
      "searchedTerms.status",
      REGEXP_STATUS_PREFIX,
      REGEXP_STATUS_MATCH
    );
    this.setSearchedTermValueForPostTime();

    this.setSearchedTermValue(
      "searchedTerms.min_posts",
      REGEXP_MIN_POSTS_PREFIX
    );

    this.setSearchedTermValue(
      "searchedTerms.max_posts",
      REGEXP_MAX_POSTS_PREFIX
    );

    this.setSearchedTermValue(
      "searchedTerms.min_views",
      REGEXP_MIN_VIEWS_PREFIX
    );

    this.setSearchedTermValue(
      "searchedTerms.max_views",
      REGEXP_MAX_VIEWS_PREFIX
    );

    if (this.model !== this._lastModel) {
      this._lastModel = this.model;
      this.submittedFilterCount = this.activeFilterCount;
    } else if (this.activeFilterCount < this.submittedFilterCount) {
      this.submittedFilterCount = this.activeFilterCount;
    }
  }

  setSearchedTermValueForIn() {
    const validValues = this.inOptions.map((option) => option.value);
    const blocks = this.filterBlocks(REGEXP_IN_PREFIX);
    const selectedFilters = [];

    for (const block of blocks) {
      let value = block.replace(REGEXP_IN_PREFIX, "").toLowerCase();
      // "in:personal" is an alias for "messages"
      if (value === "personal") {
        value = "messages";
      }
      if (validValues.includes(value) && !selectedFilters.includes(value)) {
        selectedFilters.push(value);
      }
    }

    const currentIn = this.get("searchedTerms.in") || [];
    const hasChanged =
      selectedFilters.length !== currentIn.length ||
      !selectedFilters.every((v) => currentIn.includes(v));

    if (hasChanged) {
      this.set("searchedTerms.in", selectedFilters);
    }
  }

  findSearchTerms() {
    const searchTerm = escapeExpression(this.searchTerm);
    if (!searchTerm) {
      return [];
    }

    const blocks = searchTerm.match(REGEXP_BLOCKS);
    if (!blocks) {
      return [];
    }

    let result = [];
    blocks.forEach((block) => {
      if (block.length !== 0) {
        result.push(block);
      }
    });

    return result;
  }

  filterBlocks(regexPrefix) {
    const blocks = this.findSearchTerms();
    if (!blocks) {
      return [];
    }

    let result = [];
    blocks.forEach((block) => {
      if (block.search(regexPrefix) !== -1) {
        result.push(block);
      }
    });

    return result;
  }

  setSearchedTermValue(key, replaceRegEx, matchRegEx = null) {
    matchRegEx = matchRegEx || replaceRegEx;
    const match = this.filterBlocks(matchRegEx);

    let val = this.get(key);
    if (match.length !== 0) {
      const userInput = match[0].replace(replaceRegEx, "").toLowerCase();

      if (val !== userInput && userInput.length) {
        this.set(key, userInput);
      }
    } else if (val && val.length !== 0) {
      this.set(key, null);
    }
  }

  setSearchedTermValueForCategory() {
    const match = this.filterBlocks(REGEXP_CATEGORY_PREFIX);
    if (match.length !== 0) {
      const existingInput = this.get("searchedTerms.category");
      const subcategories = match[0]
        .replace(REGEXP_CATEGORY_PREFIX, "")
        .split(":");

      let userInput;
      if (subcategories.length > 1) {
        userInput = Category.list().find(
          (category) =>
            category.get("parentCategory.slug") === subcategories[0] &&
            category.slug === subcategories[1]
        );
      } else {
        userInput = Category.list().find(
          (category) =>
            !category.parentCategory && category.slug === subcategories[0]
        );

        if (!userInput) {
          userInput = Category.list().find(
            (category) => category.slug === subcategories[0]
          );
        }
      }

      if (
        (!existingInput && userInput) ||
        (existingInput && userInput && existingInput.id !== userInput.id)
      ) {
        this.set("searchedTerms.category", userInput);
      }
    } else {
      this.set("searchedTerms.category", null);
    }
  }

  setSearchedTermValueForTags() {
    if (!this.siteSettings.tagging_enabled) {
      return;
    }

    const match = this.filterBlocks(REGEXP_TAGS_PREFIX);
    const tags = this.get("searchedTerms.tags");
    if (match.length) {
      this.set("searchedTerms.special.all_tags", match[0].includes("+"));
    }
    const containAllTags = this.get("searchedTerms.special.all_tags");

    if (match.length !== 0) {
      const joinChar = containAllTags ? "+" : ",";
      const existingInput = Array.isArray(tags) ? tags.join(joinChar) : tags;
      const userInput = match[0].replace(REGEXP_TAGS_REPLACE, "");

      if (existingInput !== userInput) {
        const updatedTags = userInput?.split(joinChar);

        this.set("searchedTerms.tags", updatedTags);
        this.set("showAllTagsCheckbox", !!(updatedTags.length > 1));
      }
    } else if (!tags) {
      this.set("searchedTerms.tags", null);
    }
  }

  setSearchedTermValueForPostTime() {
    const match = this.filterBlocks(REGEXP_POST_TIME_PREFIX);

    if (match.length !== 0) {
      const existingInputWhen = this.get("searchedTerms.time.when");
      const userInputWhen = match[0]
        .match(REGEXP_POST_TIME_WHEN)[0]
        .toLowerCase();
      const existingInputDays = this.get("searchedTerms.time.days");
      const userInputDays = match[0].replace(REGEXP_POST_TIME_PREFIX, "");
      const properties = {};

      if (existingInputWhen !== userInputWhen) {
        properties["searchedTerms.time.when"] = userInputWhen;
      }

      if (existingInputDays !== userInputDays) {
        properties["searchedTerms.time.days"] = userInputDays;
      }

      this.setProperties(properties);
    } else {
      this.set("searchedTerms.time.when", "before");
      this.set("searchedTerms.time.days", null);
    }
  }

  @action
  onChangeSearchTermMinPostCount(value) {
    this.set("searchedTerms.min_posts", value.length ? value : null);
    this._updateSearchTermForMinPostCount();
  }

  @action
  onChangeSearchTermMaxPostCount(value) {
    this.set("searchedTerms.max_posts", value.length ? value : null);
    this._updateSearchTermForMaxPostCount();
  }

  @action
  onChangeSearchTermMinViews(value) {
    this.set("searchedTerms.min_views", value.length ? value : null);
    this._updateSearchTermForMinViews();
  }

  @action
  onChangeSearchTermMaxViews(value) {
    this.set("searchedTerms.max_views", value.length ? value : null);
    this._updateSearchTermForMaxViews();
  }

  @action
  onChangeSearchTermForIn(selectedValues) {
    this.set("searchedTerms.in", selectedValues || []);
    this._updateSearchTermForIn();
  }

  @action
  onChangeSearchTermForStatus(value) {
    this.set("searchedTerms.status", value);
    this._updateSearchTermForStatus();
  }

  @action
  onChangeWhenTime(time) {
    if (time) {
      this.set("searchedTerms.time.when", time);
      this._updateSearchTermForPostTime();
    }
  }

  @action
  onChangeWhenDate(date) {
    if (date) {
      this.set("searchedTerms.time.days", date.format("YYYY-MM-DD"));
      this._updateSearchTermForPostTime();
    }
  }

  @action
  onChangeSearchTermForCategory(categoryId) {
    if (categoryId) {
      const category = Category.findById(categoryId);
      this.onChangeCategory && this.onChangeCategory(category);
      this.set("searchedTerms.category", category);
    } else {
      this.onChangeCategory && this.onChangeCategory(null);
      this.set("searchedTerms.category", null);
    }

    this._updateSearchTermForCategory();
  }

  @action
  onChangeSearchTermForUsername(username) {
    this.set("searchedTerms.username", username.length ? username : null);
    this._updateSearchTermForUsername();
  }

  @action
  onChangeSearchTermForTags(tags) {
    const tagNames = tags.map((t) => (typeof t === "object" ? t.name : t));
    this.set("searchedTerms.tags", tagNames.length ? tagNames : null);
    this._updateSearchTermForTags();
  }

  @action
  onChangeSearchTermForAllTags(event) {
    this.set("searchedTerms.special.all_tags", event.target.checked);
    this._updateSearchTermForTags();
  }

  @action
  onChangeSearchedTermField(path, updateFnName, value) {
    this.set(`searchedTerms.${path}`, value);
    this[updateFnName]();
  }

  @action
  toggleFilters() {
    this.isExpanded = !this.isExpanded;
  }

  @action
  _collapseFilters() {
    this.isExpanded = false;
  }

  _updateSearchTermForTags() {
    const match = this.filterBlocks(REGEXP_TAGS_PREFIX);
    const tagFilter = this.get("searchedTerms.tags");
    let searchTerm = this.searchTerm || "";
    const containAllTags = this.get("searchedTerms.special.all_tags");

    if (tagFilter && tagFilter.length !== 0) {
      const joinChar = containAllTags ? "+" : ",";
      const tags = tagFilter.join(joinChar);

      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], `tags:${tags}`);
      } else {
        searchTerm += ` tags:${tags}`;
      }

      if (tagFilter.length > 1) {
        this.set("showAllTagsCheckbox", true);
      }
      this._updateSearchTerm(searchTerm);
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], "");
      this._updateSearchTerm(searchTerm);
    }
  }

  _updateSearchTermForCategory() {
    const match = this.filterBlocks(REGEXP_CATEGORY_PREFIX);
    const categoryFilter = this.get("searchedTerms.category");
    let searchTerm = this.searchTerm || "";

    const slugCategoryMatches =
      match.length !== 0 ? match[0].match(REGEXP_CATEGORY_SLUG) : null;
    const idCategoryMatches =
      match.length !== 0 ? match[0].match(REGEXP_CATEGORY_ID) : null;
    if (categoryFilter) {
      const id = categoryFilter.id;
      const slug = categoryFilter.slug;
      if (categoryFilter.parentCategory) {
        const parentSlug = categoryFilter.parentCategory.slug;
        if (slugCategoryMatches) {
          searchTerm = searchTerm.replace(
            slugCategoryMatches[0],
            `#${parentSlug}:${slug}`
          );
        } else if (idCategoryMatches) {
          searchTerm = searchTerm.replace(
            idCategoryMatches[0],
            `category:${id}`
          );
        } else if (slug) {
          searchTerm += ` #${parentSlug}:${slug}`;
        } else {
          searchTerm += ` category:${id}`;
        }

        this._updateSearchTerm(searchTerm);
      } else {
        if (slugCategoryMatches) {
          searchTerm = searchTerm.replace(slugCategoryMatches[0], `#${slug}`);
        } else if (idCategoryMatches) {
          searchTerm = searchTerm.replace(
            idCategoryMatches[0],
            `category:${id}`
          );
        } else if (slug) {
          searchTerm += ` #${slug}`;
        } else {
          searchTerm += ` category:${id}`;
        }

        this._updateSearchTerm(searchTerm);
      }
    } else {
      if (slugCategoryMatches) {
        searchTerm = searchTerm.replace(slugCategoryMatches[0], "");
      }
      if (idCategoryMatches) {
        searchTerm = searchTerm.replace(idCategoryMatches[0], "");
      }

      this._updateSearchTerm(searchTerm);
    }
  }

  _updateSearchTermForUsername() {
    const match = this.filterBlocks(REGEXP_USERNAME_PREFIX);
    const userFilter = this.get("searchedTerms.username");
    let searchTerm = this.searchTerm || "";

    if (userFilter && userFilter.length !== 0) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], `@${userFilter}`);
      } else {
        searchTerm += ` @${userFilter}`;
      }

      this._updateSearchTerm(searchTerm);
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], "");
      this._updateSearchTerm(searchTerm);
    }
  }

  _updateSearchTermForPostTime() {
    const match = this.filterBlocks(REGEXP_POST_TIME_PREFIX);
    const timeDaysFilter = this.get("searchedTerms.time.days");
    let searchTerm = this.searchTerm || "";

    if (timeDaysFilter) {
      const when = this.get("searchedTerms.time.when");
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], `${when}:${timeDaysFilter}`);
      } else {
        searchTerm += ` ${when}:${timeDaysFilter}`;
      }

      this._updateSearchTerm(searchTerm);
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], "");
      this._updateSearchTerm(searchTerm);
    }
  }

  _updateSearchTermForIn() {
    let searchTerm = this.searchTerm || "";
    const selectedFilters = this.get("searchedTerms.in") || [];

    // Remove all existing in:/with: filters that match our options
    const allFilterValues = this.inOptions.map((option) => option.value);
    // Also include "personal" as an alias for "messages"
    allFilterValues.push("personal");

    const regExpAllIn = new RegExp(
      `\\s*(in|with):(${allFilterValues.join("|")})`,
      "gi"
    );
    searchTerm = searchTerm.replace(regExpAllIn, "");

    // Add the selected filters
    selectedFilters.forEach((filter) => {
      let keyword = "in";
      if (filter in IN_OPTIONS_MAPPING) {
        keyword = IN_OPTIONS_MAPPING[filter];
      }
      searchTerm += ` ${keyword}:${filter}`;
    });

    this._updateSearchTerm(searchTerm);
  }

  _updateSearchTermForStatus() {
    let regExpStatusMatch = this.statusOptions
      .map((status) => status.value)
      .join("|");
    const REGEXP_STATUS_MATCH = new RegExp(
      `status:(${regExpStatusMatch})`,
      "i"
    );

    const match = this.filterBlocks(REGEXP_STATUS_MATCH);
    const statusFilter = this.get("searchedTerms.status");
    let searchTerm = this.searchTerm || "";

    if (statusFilter) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], `status:${statusFilter}`);
      } else {
        searchTerm += ` status:${statusFilter}`;
      }

      this._updateSearchTerm(searchTerm);
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], "");
      this._updateSearchTerm(searchTerm);
    }
  }

  _updateSearchTermForMinPostCount() {
    const match = this.filterBlocks(REGEXP_MIN_POSTS_PREFIX);
    const postsCountFilter = this.get("searchedTerms.min_posts");
    let searchTerm = this.searchTerm || "";

    if (postsCountFilter) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(
          match[0],
          `min_posts:${postsCountFilter}`
        );
      } else {
        searchTerm += ` min_posts:${postsCountFilter}`;
      }

      this._updateSearchTerm(searchTerm);
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], "");
      this._updateSearchTerm(searchTerm);
    }
  }

  _updateSearchTermForMaxPostCount() {
    const match = this.filterBlocks(REGEXP_MAX_POSTS_PREFIX);
    const postsCountFilter = this.get("searchedTerms.max_posts");
    let searchTerm = this.searchTerm || "";

    if (postsCountFilter) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(
          match[0],
          `max_posts:${postsCountFilter}`
        );
      } else {
        searchTerm += ` max_posts:${postsCountFilter}`;
      }

      this._updateSearchTerm(searchTerm);
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], "");
      this._updateSearchTerm(searchTerm);
    }
  }

  _updateSearchTermForMinViews() {
    const match = this.filterBlocks(REGEXP_MIN_VIEWS_PREFIX);
    const viewsCountFilter = this.get("searchedTerms.min_views");
    let searchTerm = this.searchTerm || "";

    if (viewsCountFilter) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(
          match[0],
          `min_views:${viewsCountFilter}`
        );
      } else {
        searchTerm += ` min_views:${viewsCountFilter}`;
      }

      this._updateSearchTerm(searchTerm);
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], "");
      this._updateSearchTerm(searchTerm);
    }
  }

  _updateSearchTermForMaxViews() {
    const match = this.filterBlocks(REGEXP_MAX_VIEWS_PREFIX);
    const viewsCountFilter = this.get("searchedTerms.max_views");
    let searchTerm = this.searchTerm || "";

    if (viewsCountFilter) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(
          match[0],
          `max_views:${viewsCountFilter}`
        );
      } else {
        searchTerm += ` max_views:${viewsCountFilter}`;
      }

      this._updateSearchTerm(searchTerm);
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match[0], "");
      this._updateSearchTerm(searchTerm);
    }
  }

  _updateSearchTerm(searchTerm) {
    this.onChangeSearchTerm(searchTerm.trim());
  }

  <template>
    <div
      class={{dConcatClass
        "advanced-filters"
        (if this.isExpanded "--is-expanded")
      }}
      ...attributes
    >
      <DButton
        class="advanced-filters__toggle btn-default"
        @action={{this.toggleFilters}}
        @ariaExpanded={{this.isExpanded}}
        @ariaLabel={{i18n "search.advanced.title"}}
      >
        {{#if this.submittedFilterCount}}
          <span class="badge-notification">{{this.submittedFilterCount}}</span>
        {{/if}}
        {{i18n "search.advanced.title"}}
        {{dIcon (if this.isExpanded "chevron-up" "chevron-down")}}
      </DButton>
      <PluginOutlet
        @name="full-page-search-advanced-header"
        @outletArgs={{lazyHash
          sortOrder=@sortOrder
          type=@searchType
          addSearchResults=@addSearchResults
          model=@model
          searchTerm=@searchTerm
        }}
      />
      {{#if this.isExpanded}}
        <div class="search-advanced-filters">
          <div class="search-advanced-options">
            <PluginOutlet
              @connectorTagName="div"
              @name="advanced-search-options-above"
              @outletArgs={{lazyHash
                searchedTerms=this.searchedTerms
                onChangeSearchedTermField=this.onChangeSearchedTermField
              }}
            />

            <div class="control-group advanced-search-category">
              <label class="control-label">
                {{i18n "search.advanced.in_category.label"}}
              </label>
              <div class="controls">
                <SearchAdvancedCategoryChooser
                  @id="search-in-category"
                  @onChange={{this.onChangeSearchTermForCategory}}
                  @value={{this.searchedTerms.category.id}}
                />
              </div>
            </div>

            {{#if this.siteSettings.tagging_enabled}}
              <div class="control-group advanced-search-tags">
                <label class="control-label">
                  {{i18n "search.advanced.with_tags.label"}}
                </label>
                <div class="controls">
                  <TagChooser
                    @everyTag={{true}}
                    @id="search-with-tags"
                    @onChange={{this.onChangeSearchTermForTags}}
                    @options={{hash
                      allowAny=false
                      headerAriaLabel=(i18n
                        "search.advanced.with_tags.aria_label"
                      )
                    }}
                    @tags={{this.searchedTerms.tags}}
                    @unlimitedTagCount={{true}}
                  />
                  {{#if this.showAllTagsCheckbox}}
                    <section class="field">
                      <label>
                        <Input
                          class="all-tags"
                          @checked={{this.searchedTerms.special.all_tags}}
                          @type="checkbox"
                          {{on "click" this.onChangeSearchTermForAllTags}}
                        />
                        {{i18n "search.advanced.filters.all_tags"}}
                      </label>
                    </section>
                  {{/if}}
                </div>
              </div>
            {{/if}}

            <div class="control-group advanced-search-topics-posts">
              <label class="control-label">
                {{i18n "search.advanced.filters.label"}}
              </label>
              <div class="controls">
                <MultiSelect
                  @content={{this.inOptions}}
                  @id="search-in-options"
                  @onChange={{this.onChangeSearchTermForIn}}
                  @options={{hash
                    headerAriaLabel=(i18n "search.advanced.filters.label")
                  }}
                  @value={{this.searchedTerms.in}}
                  @valueProperty="value"
                />
              </div>
            </div>

            <div class="control-group advanced-search-topic-status">
              <label class="control-label">
                {{i18n "search.advanced.statuses.label"}}
              </label>
              <div class="controls">
                <ComboBox
                  @content={{this.statusOptions}}
                  @id="search-status-options"
                  @onChange={{this.onChangeSearchTermForStatus}}
                  @options={{hash
                    none="user.locale.any"
                    headerAriaLabel=(i18n "search.advanced.statuses.label")
                    clearable=true
                  }}
                  @value={{this.searchedTerms.status}}
                  @valueProperty="value"
                />
              </div>
            </div>

            <div class="control-group advanced-search-posted-by">
              <label class="control-label">
                {{i18n "search.advanced.posted_by.label"}}
              </label>
              <div class="controls">
                <UserChooser
                  @id="search-posted-by"
                  @onChange={{this.onChangeSearchTermForUsername}}
                  @options={{hash
                    headerAriaLabel=(i18n
                      "search.advanced.posted_by.aria_label"
                    )
                    maximum=1
                    excludeCurrentUser=false
                  }}
                  @value={{this.searchedTerms.username}}
                />
              </div>
            </div>

            <div class="control-group advanced-search-posted-date">
              <label class="control-label">{{i18n
                  "search.advanced.post.time.label"
                }}</label>
              <div class="controls inline-form">
                <ComboBox
                  @content={{this.postTimeOptions}}
                  @id="postTime"
                  @onChange={{this.onChangeWhenTime}}
                  @value={{this.searchedTerms.time.when}}
                  @valueProperty="value"
                />
                <DDateInput
                  aria-label={{i18n "search.advanced.post.time.aria_label"}}
                  @date={{this.searchedTerms.time.days}}
                  @inputId="search-post-date"
                  @onChange={{this.onChangeWhenDate}}
                />
              </div>
            </div>

            <div class="count-group control-group">
              <label class="control-label">
                {{i18n "search.advanced.post.count.label"}}
              </label>
              <div class="controls">
                <Input
                  aria-label={{i18n "search.advanced.post.min.aria_label"}}
                  class="input-small"
                  id="search-min-post-count"
                  placeholder={{i18n "search.advanced.post.min.placeholder"}}
                  @type="number"
                  @value={{readonly this.searchedTerms.min_posts}}
                  {{on
                    "input"
                    (withEventValue this.onChangeSearchTermMinPostCount)
                  }}
                />
                {{dIcon "left-right"}}
                <Input
                  aria-label={{i18n "search.advanced.post.max.aria_label"}}
                  class="input-small"
                  id="search-max-post-count"
                  placeholder={{i18n "search.advanced.post.max.placeholder"}}
                  @type="number"
                  @value={{readonly this.searchedTerms.max_posts}}
                  {{on
                    "input"
                    (withEventValue this.onChangeSearchTermMaxPostCount)
                  }}
                />
              </div>
            </div>

            <div class="count-group control-group">
              <label class="control-label">
                {{i18n "search.advanced.views.label"}}
              </label>
              <div class="controls">
                <Input
                  aria-label={{i18n "search.advanced.min_views.aria_label"}}
                  class="input-small"
                  id="search-min-views"
                  placeholder={{i18n "search.advanced.min_views.placeholder"}}
                  @type="number"
                  @value={{readonly this.searchedTerms.min_views}}
                  {{on
                    "input"
                    (withEventValue this.onChangeSearchTermMinViews)
                  }}
                />
                {{dIcon "left-right"}}
                <Input
                  aria-label={{i18n "search.advanced.max_views.aria_label"}}
                  class="input-small"
                  id="search-max-views"
                  placeholder={{i18n "search.advanced.max_views.placeholder"}}
                  @type="number"
                  @value={{readonly this.searchedTerms.max_views}}
                  {{on
                    "input"
                    (withEventValue this.onChangeSearchTermMaxViews)
                  }}
                />
              </div>
            </div>

            <PluginOutlet
              @connectorTagName="div"
              @name="advanced-search-options-below"
              @outletArgs={{lazyHash
                searchedTerms=this.searchedTerms
                onChangeSearchedTermField=this.onChangeSearchedTermField
              }}
            />
          </div>

          {{#if this.site.mobileView}}
            <div class="second-search-button">
              <DButton
                class="btn-primary search-cta"
                @action={{this.search}}
                @ariaLabel="search.search_button"
                @disabled={{this.searchButtonDisabled}}
                @icon="magnifying-glass"
                @label="search.search_button"
              />
            </div>
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
