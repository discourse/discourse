import Category from "discourse/models/category";
import { readOnly, or, equal, gte } from "@ember/object/computed";
import { i18n, setting } from "discourse/lib/computed";
import ComboBoxComponent from "select-kit/components/combo-box";
import DiscourseURL from "discourse/lib/url";
import TagsMixin from "select-kit/mixins/tags";
import { computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { makeArray } from "discourse-common/lib/helpers";

export const NO_TAG_ID = "no-tags";
export const ALL_TAGS_ID = "all-tags";
export const NONE_TAG_ID = "none";

export default ComboBoxComponent.extend(TagsMixin, {
  pluginApiIdentifiers: ["tag-drop"],
  classNameBindings: ["categoryStyle", "tagClass"],
  classNames: ["tag-drop"],
  value: readOnly("tagId"),
  tagName: "li",
  currentCategory: or("secondCategory", "firstCategory"),
  showFilterByTag: setting("show_filter_by_tag"),
  categoryStyle: setting("category_style"),
  maxTagSearchResults: setting("max_tag_search_results"),
  sortTagsAlphabetically: setting("tags_sort_alphabetically"),
  isVisible: computed("showFilterByTag", "content.[]", function() {
    if (this.showFilterByTag && !isEmpty(this.content)) {
      return true;
    }

    return false;
  }),

  selectKitOptions: {
    allowAny: false,
    caretDownIcon: "caret-right",
    caretUpIcon: "caret-down",
    fullWidthOnMobile: true,
    filterable: true,
    headerComponent: "tag-drop/tag-drop-header",
    autoInsertNoneItem: false
  },

  noTagsSelected: equal("tagId", NONE_TAG_ID),

  filterable: gte("content.length", 15),

  modifyNoSelection() {
    if (this.noTagsSelected) {
      return this.defaultItem(NO_TAG_ID, this.noTagsLabel);
    } else {
      return this.defaultItem(ALL_TAGS_ID, this.allTagsLabel);
    }
  },

  modifySelection(content) {
    if (this.tagId) {
      if (this.noTagsSelected) {
        content = this.defaultItem(NO_TAG_ID, this.noTagsLabel);
      } else {
        content = this.defaultItem(this.tagId, this.tagId);
      }
    }

    return content;
  },

  tagClass: computed("tagId", function() {
    return this.tagId ? `tag-${this.tagId}` : "tag_all";
  }),

  currentCategoryUrl: readOnly("currentCategory.url"),

  allTagsUrl: computed("firstCategory", "secondCategory", function() {
    if (this.currentCategory) {
      return Discourse.getURL(`${this.currentCategoryUrl}?allTags=1`);
    } else {
      return Discourse.getURL("/");
    }
  }),

  noTagsUrl: computed("firstCategory", "secondCategory", function() {
    let url = "/tags";
    if (this.currentCategory) {
      url += `/c/${Category.slugFor(this.currentCategory)}/${
        this.currentCategory.id
      }`;
    }
    return Discourse.getURL(`${url}/${NONE_TAG_ID}`);
  }),

  allTagsLabel: i18n("tagging.selector_all_tags"),

  noTagsLabel: i18n("tagging.selector_no_tags"),

  shortcuts: computed("tagId", function() {
    const shortcuts = [];

    if (this.tagId !== NONE_TAG_ID) {
      shortcuts.push(NO_TAG_ID);
    }

    if (this.tagId) {
      shortcuts.push(ALL_TAGS_ID);
    }

    return shortcuts;
  }),

  topTags: readOnly("site.top_tags.[]"),

  content: computed("topTags.[]", "shortcuts.[]", function() {
    if (this.sortTagsAlphabetically && this.topTags) {
      return this.shortcuts.concat(this.topTags.sort());
    } else {
      return this.shortcuts.concat(makeArray(this.topTags));
    }
  }),

  search(filter) {
    if (filter) {
      const data = {
        q: filter,
        limit: this.maxTagSearchResults
      };

      return this.searchTags("/tags/filter/search", data, this._transformJson);
    } else {
      return (this.content || []).map(tag => this.defaultItem(tag, tag));
    }
  },

  _transformJson(context, json) {
    return json.results
      .sort((a, b) => a.id > b.id)
      .map(r => {
        const content = context.defaultItem(r.id, r.text);
        content.targetTagId = r.target_tag || r.id;
        content.count = r.count;
        content.pmCount = r.pm_count;
        return content;
      });
  },

  actions: {
    onChange(tagId, tag) {
      let url;

      switch (tagId) {
        case ALL_TAGS_ID:
          url = this.allTagsUrl;
          break;
        case NO_TAG_ID:
          url = this.noTagsUrl;
          break;
        default:
          if (this.currentCategory) {
            url = `/tags/c/${Category.slugFor(this.currentCategory)}/${
              this.currentCategory.id
            }`;
          } else {
            url = "/tag";
          }

          if (tag && tag.targetTagId) {
            url += `/${tag.targetTagId.toLowerCase()}`;
          } else {
            url += `/${tagId.toLowerCase()}`;
          }
      }

      DiscourseURL.routeTo(Discourse.getURL(url));
    }
  }
});
