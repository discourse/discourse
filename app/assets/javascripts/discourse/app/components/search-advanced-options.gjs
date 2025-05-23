import Component, { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import {
  attributeBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import DateInput from "discourse/components/date-input";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import SearchAdvancedCategoryChooser from "select-kit/components/search-advanced-category-chooser";
import TagChooser from "select-kit/components/tag-chooser";
import UserChooser from "select-kit/components/user-chooser";

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

const REGEXP_SPECIAL_IN_LIKES_MATCH = /^in:likes$/gi;
const REGEXP_SPECIAL_IN_TITLE_MATCH = /^in:title$/gi;
const REGEXP_SPECIAL_IN_MESSAGES_MATCH = /^in:(personal|messages)$/gi;
const REGEXP_SPECIAL_IN_SEEN_MATCH = /^in:seen$/gi;

const REGEXP_CATEGORY_SLUG = /^(\#[a-zA-Z0-9\-:]+)/gi;
const REGEXP_CATEGORY_ID = /^(category:[0-9]+)/gi;
const REGEXP_POST_TIME_WHEN = /^(before|after)/gi;

const IN_OPTIONS_MAPPING = { images: "with" };

let _extraOptions = [];

function inOptionsForUsers() {
  return [
    { name: i18n("search.advanced.filters.unseen"), value: "unseen" },
    { name: i18n("search.advanced.filters.posted"), value: "posted" },
    { name: i18n("search.advanced.filters.created"), value: "created" },
    { name: i18n("search.advanced.filters.watching"), value: "watching" },
    { name: i18n("search.advanced.filters.tracking"), value: "tracking" },
    { name: i18n("search.advanced.filters.bookmarks"), value: "bookmarks" },
  ].concat(..._extraOptions.map((eo) => eo.inOptionsForUsers).filter(Boolean));
}

function inOptionsForAll() {
  return [
    { name: i18n("search.advanced.filters.first"), value: "first" },
    { name: i18n("search.advanced.filters.pinned"), value: "pinned" },
    { name: i18n("search.advanced.filters.wiki"), value: "wiki" },
    { name: i18n("search.advanced.filters.images"), value: "images" },
  ].concat(..._extraOptions.map((eo) => eo.inOptionsForAll).filter(Boolean));
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

@tagName("details")
@attributeBindings("expandFilters:open")
@classNames("advanced-filters")
export default class SearchAdvancedOptions extends Component {
  category = null;

  init() {
    super.init(...arguments);

    this.setProperties({
      searchedTerms: {
        username: null,
        category: null,
        tags: null,
        in: null,
        special: {
          in: {
            title: false,
            likes: false,
            messages: false,
            seen: false,
          },
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

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    this.setSearchedTermValue("searchedTerms.username", REGEXP_USERNAME_PREFIX);
    this.setSearchedTermValueForCategory();
    this.setSearchedTermValueForTags();

    let regExpInMatch = this.inOptions.map((option) => option.value).join("|");
    const REGEXP_IN_MATCH = new RegExp(`(in|with):(${regExpInMatch})`, "i");

    this.setSearchedTermValue(
      "searchedTerms.in",
      REGEXP_IN_PREFIX,
      REGEXP_IN_MATCH
    );

    this.setSearchedTermSpecialInValue(
      "searchedTerms.special.in.likes",
      REGEXP_SPECIAL_IN_LIKES_MATCH
    );

    this.setSearchedTermSpecialInValue(
      "searchedTerms.special.in.title",
      REGEXP_SPECIAL_IN_TITLE_MATCH
    );

    this.setSearchedTermSpecialInValue(
      "searchedTerms.special.in.messages",
      REGEXP_SPECIAL_IN_MESSAGES_MATCH
    );

    this.setSearchedTermSpecialInValue(
      "searchedTerms.special.in.seen",
      REGEXP_SPECIAL_IN_SEEN_MATCH
    );

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

  setSearchedTermSpecialInValue(key, replaceRegEx) {
    const match = this.filterBlocks(replaceRegEx);

    if (match.length !== 0) {
      if (this.get(key) !== true) {
        this.set(key, true);
      }
    } else if (this.get(key) !== false) {
      this.set(key, false);
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

  updateInRegex(regex, filter) {
    const match = this.filterBlocks(regex);
    const inFilter = this.get("searchedTerms.special.in." + filter);
    let searchTerm = this.searchTerm || "";

    if (inFilter) {
      if (match.length === 0) {
        searchTerm += ` in:${filter}`;
        this._updateSearchTerm(searchTerm);
      }
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match, "");
      this._updateSearchTerm(searchTerm);
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
  onChangeSearchTermForIn(value) {
    this.set("searchedTerms.in", value);
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
    this.set("searchedTerms.tags", tags.length ? tags : null);
    this._updateSearchTermForTags();
  }

  @action
  onChangeSearchTermForAllTags(event) {
    this.set("searchedTerms.special.all_tags", event.target.checked);
    this._updateSearchTermForTags();
  }

  @action
  onChangeSearchTermForSpecialInLikes(event) {
    this.set("searchedTerms.special.in.likes", event.target.checked);
    this.updateInRegex(REGEXP_SPECIAL_IN_LIKES_MATCH, "likes");
  }

  @action
  onChangeSearchTermForSpecialInMessages(event) {
    this.set("searchedTerms.special.in.messages", event.target.checked);
    this.updateInRegex(REGEXP_SPECIAL_IN_MESSAGES_MATCH, "messages");
  }

  @action
  onChangeSearchTermForSpecialInSeen(event) {
    this.set("searchedTerms.special.in.seen", event.target.checked);
    this.updateInRegex(REGEXP_SPECIAL_IN_SEEN_MATCH, "seen");
  }

  @action
  onChangeSearchTermForSpecialInTitle(event) {
    this.set("searchedTerms.special.in.title", event.target.checked);
    this.updateInRegex(REGEXP_SPECIAL_IN_TITLE_MATCH, "title");
  }

  @action
  onChangeSearchedTermField(path, updateFnName, value) {
    this.set(`searchedTerms.${path}`, value);
    this[updateFnName]();
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
    let regExpInMatch = this.inOptions.map((option) => option.value).join("|");
    const REGEXP_IN_MATCH = new RegExp(`(in|with):(${regExpInMatch})`, "i");

    const match = this.filterBlocks(REGEXP_IN_MATCH);
    const inFilter = this.get("searchedTerms.in");
    let keyword = "in";
    if (inFilter in IN_OPTIONS_MAPPING) {
      keyword = IN_OPTIONS_MAPPING[inFilter];
    }
    let searchTerm = this.searchTerm || "";

    if (inFilter) {
      if (match.length !== 0) {
        searchTerm = searchTerm.replace(match[0], `${keyword}:${inFilter}`);
      } else {
        searchTerm += ` ${keyword}:${inFilter}`;
      }

      this._updateSearchTerm(searchTerm);
    } else if (match.length !== 0) {
      searchTerm = searchTerm.replace(match, "");
      this._updateSearchTerm(searchTerm);
    }
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
    {{! template-lint-disable no-nested-interactive }}
    <summary>
      {{i18n "search.advanced.title"}}
    </summary>
    <div class="search-advanced-filters">
      <div class="search-advanced-options">
        <PluginOutlet
          @name="advanced-search-options-above"
          @connectorTagName="div"
          @outletArgs={{lazyHash
            searchedTerms=this.searchedTerms
            onChangeSearchedTermField=this.onChangeSearchedTermField
          }}
        />

        <div class="control-group advanced-search-category">
          <label class="control-label">{{i18n
              "search.advanced.in_category.label"
            }}</label>
          <div class="controls">
            <SearchAdvancedCategoryChooser
              @id="search-in-category"
              @value={{this.searchedTerms.category.id}}
              @onChange={{this.onChangeSearchTermForCategory}}
            />
          </div>
        </div>

        {{#if this.siteSettings.tagging_enabled}}
          <div class="control-group advanced-search-tags">
            <label class="control-label">{{i18n
                "search.advanced.with_tags.label"
              }}</label>
            <div class="controls">
              <TagChooser
                @id="search-with-tags"
                @tags={{this.searchedTerms.tags}}
                @everyTag={{true}}
                @unlimitedTagCount={{true}}
                @onChange={{this.onChangeSearchTermForTags}}
                @options={{hash
                  allowAny=false
                  headerAriaLabel=(i18n "search.advanced.with_tags.aria_label")
                }}
              />
              {{#if this.showAllTagsCheckbox}}
                <section class="field">
                  <label>
                    <Input
                      @type="checkbox"
                      class="all-tags"
                      @checked={{this.searchedTerms.special.all_tags}}
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
          <div class="controls">
            <fieldset class="grouped-control">
              <legend class="grouped-control-label">{{i18n
                  "search.advanced.filters.label"
                }}</legend>

              {{#if this.currentUser}}
                <div class="grouped-control-field">
                  <Input
                    id="matching-title-only"
                    @type="checkbox"
                    class="in-title"
                    @checked={{this.searchedTerms.special.in.title}}
                    {{on "click" this.onChangeSearchTermForSpecialInTitle}}
                  />
                  <label class="checkbox-label" for="matching-title-only">
                    {{i18n "search.advanced.filters.title"}}
                  </label>
                </div>

                <div class="grouped-control-field">
                  <Input
                    id="matching-liked"
                    @type="checkbox"
                    class="in-likes"
                    @checked={{this.searchedTerms.special.in.likes}}
                    {{on "click" this.onChangeSearchTermForSpecialInLikes}}
                  />
                  <label class="checkbox-label" for="matching-liked">{{i18n
                      "search.advanced.filters.likes"
                    }}</label>
                </div>

                <div class="grouped-control-field">
                  <Input
                    id="matching-in-messages"
                    @type="checkbox"
                    class="in-private"
                    @checked={{this.searchedTerms.special.in.messages}}
                    {{on "click" this.onChangeSearchTermForSpecialInMessages}}
                  />
                  <label
                    class="checkbox-label"
                    for="matching-in-messages"
                  >{{i18n "search.advanced.filters.private"}}</label>
                </div>

                <div class="grouped-control-field">
                  <Input
                    id="matching-seen"
                    @type="checkbox"
                    class="in-seen"
                    @checked={{this.searchedTerms.special.in.seen}}
                    {{on "click" this.onChangeSearchTermForSpecialInSeen}}
                  />
                  <label class="checkbox-label" for="matching-seen">{{i18n
                      "search.advanced.filters.seen"
                    }}</label>
                </div>
              {{/if}}

              <ComboBox
                @id="in"
                @valueProperty="value"
                @content={{this.inOptions}}
                @value={{this.searchedTerms.in}}
                @onChange={{this.onChangeSearchTermForIn}}
                @options={{hash none="user.locale.any" clearable=true}}
              />
            </fieldset>
          </div>
        </div>

        <div class="control-group advanced-search-topic-status">
          <label class="control-label">{{i18n
              "search.advanced.statuses.label"
            }}</label>
          <div class="controls">
            <ComboBox
              @id="search-status-options"
              @valueProperty="value"
              @content={{this.statusOptions}}
              @value={{this.searchedTerms.status}}
              @onChange={{this.onChangeSearchTermForStatus}}
              @options={{hash
                none="user.locale.any"
                headerAriaLabel=(i18n "search.advanced.statuses.label")
                clearable=true
              }}
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
              @value={{this.searchedTerms.username}}
              @onChange={{this.onChangeSearchTermForUsername}}
              @options={{hash
                headerAriaLabel=(i18n "search.advanced.posted_by.aria_label")
                maximum=1
                excludeCurrentUser=false
              }}
            />
          </div>
        </div>

        <div class="control-group advanced-search-posted-date">
          <label class="control-label">{{i18n
              "search.advanced.post.time.label"
            }}</label>
          <div class="controls inline-form">
            <ComboBox
              @id="postTime"
              @valueProperty="value"
              @content={{this.postTimeOptions}}
              @value={{this.searchedTerms.time.when}}
              @onChange={{this.onChangeWhenTime}}
              @options={{hash
                headerAriaLabel=(i18n "search.advanced.post.time.aria_label")
              }}
            />
            <DateInput
              @date={{this.searchedTerms.time.days}}
              @onChange={{this.onChangeWhenDate}}
              @inputId="search-post-date"
            />
          </div>
        </div>

        <PluginOutlet
          @name="advanced-search-options-below"
          @connectorTagName="div"
          @outletArgs={{lazyHash
            searchedTerms=this.searchedTerms
            onChangeSearchedTermField=this.onChangeSearchedTermField
          }}
        />
      </div>

      <details class="search-advanced-additional-options">
        <summary>
          {{i18n "search.advanced.additional_options.label"}}
        </summary>
        <div class="count-group control-group">
          {{! TODO: Using a label here fails no-nested-interactive lint rule }}
          <span class="control-label">{{i18n
              "search.advanced.post.count.label"
            }}</span>
          <div class="controls">
            <Input
              @type="number"
              @value={{readonly this.searchedTerms.min_posts}}
              class="input-small"
              id="search-min-post-count"
              placeholder={{i18n "search.advanced.post.min.placeholder"}}
              aria-label={{i18n "search.advanced.post.min.aria_label"}}
              {{on
                "input"
                (withEventValue this.onChangeSearchTermMinPostCount)
              }}
            />
            {{icon "left-right"}}
            <Input
              @type="number"
              @value={{readonly this.searchedTerms.max_posts}}
              class="input-small"
              id="search-max-post-count"
              placeholder={{i18n "search.advanced.post.max.placeholder"}}
              aria-label={{i18n "search.advanced.post.max.aria_label"}}
              {{on
                "input"
                (withEventValue this.onChangeSearchTermMaxPostCount)
              }}
            />
          </div>
        </div>

        <div class="count-group control-group">
          {{! TODO: Using a label here fails no-nested-interactive lint rule }}
          <span class="control-label">{{i18n
              "search.advanced.views.label"
            }}</span>
          <div class="controls">
            <Input
              @type="number"
              @value={{readonly this.searchedTerms.min_views}}
              class="input-small"
              id="search-min-views"
              placeholder={{i18n "search.advanced.min_views.placeholder"}}
              aria-label={{i18n "search.advanced.min_views.aria_label"}}
              {{on "input" (withEventValue this.onChangeSearchTermMinViews)}}
            />
            {{icon "left-right"}}
            <Input
              @type="number"
              @value={{readonly this.searchedTerms.max_views}}
              class="input-small"
              id="search-max-views"
              placeholder={{i18n "search.advanced.max_views.placeholder"}}
              aria-label={{i18n "search.advanced.max_views.aria_label"}}
              {{on "input" (withEventValue this.onChangeSearchTermMaxViews)}}
            />
          </div>
        </div>
      </details>

      {{#if this.site.mobileView}}
        <div class="second-search-button">
          <DButton
            @action={{this.search}}
            @icon="magnifying-glass"
            @label="search.search_button"
            @ariaLabel="search.search_button"
            @disabled={{this.searchButtonDisabled}}
            class="btn-primary search-cta"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
