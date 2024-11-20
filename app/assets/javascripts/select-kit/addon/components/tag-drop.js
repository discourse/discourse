import { action, computed } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import { classNameBindings, classNames } from "@ember-decorators/component";
import { setting } from "discourse/lib/computed";
import DiscourseURL, { getCategoryAndTagUrl } from "discourse/lib/url";
import { makeArray } from "discourse-common/lib/helpers";
import { i18n } from "discourse-i18n";
import ComboBoxComponent from "select-kit/components/combo-box";
import FilterForMore from "select-kit/components/filter-for-more";
import {
  MAIN_COLLECTION,
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";
import TagsMixin from "select-kit/mixins/tags";

export const NO_TAG_ID = "no-tags";
export const ALL_TAGS_ID = "all-tags";

export const NONE_TAG = "none";

const MORE_TAGS_COLLECTION = "MORE_TAGS_COLLECTION";

@classNameBindings("tagClass")
@classNames("tag-drop")
@selectKitOptions({
  allowAny: false,
  caretDownIcon: "caret-right",
  caretUpIcon: "caret-down",
  fullWidthOnMobile: true,
  filterable: true,
  headerComponent: "tag-drop/tag-drop-header",
  autoInsertNoneItem: false,
})
@pluginApiIdentifiers("tag-drop")
export default class TagDrop extends ComboBoxComponent.extend(TagsMixin) {
  @setting("max_tag_search_results") maxTagSearchResults;
  @setting("tags_sort_alphabetically") sortTagsAlphabetically;
  @setting("max_tags_in_filter_list") maxTagsInFilterList;

  @readOnly("tagId") value;

  @computed("maxTagsInFilterList", "topTags.[]", "mainCollection.[]")
  get shouldShowMoreTags() {
    if (this.selectKit.filter?.length > 0) {
      return this.mainCollection.length > this.maxTagsInFilterList;
    } else {
      return this.topTags.length > this.maxTagsInFilterList;
    }
  }

  init() {
    super.init(...arguments);

    this.insertAfterCollection(MAIN_COLLECTION, MORE_TAGS_COLLECTION);
  }

  modifyComponentForCollection(collection) {
    if (collection === MORE_TAGS_COLLECTION) {
      return FilterForMore;
    }
  }

  modifyContentForCollection(collection) {
    if (collection === MORE_TAGS_COLLECTION) {
      return {
        shouldShowMoreTip: this.shouldShowMoreTags,
      };
    }
  }

  modifyNoSelection() {
    if (this.tagId === NONE_TAG) {
      return this.defaultItem(NO_TAG_ID, i18n("tagging.selector_no_tags"));
    } else {
      return this.defaultItem(ALL_TAGS_ID, i18n("tagging.selector_tags"));
    }
  }

  modifySelection(content) {
    if (this.tagId === NONE_TAG) {
      content = this.defaultItem(NO_TAG_ID, i18n("tagging.selector_no_tags"));
    } else if (this.tagId) {
      content = this.defaultItem(this.tagId, this.tagId);
    }

    return content;
  }

  @computed("tagId")
  get tagClass() {
    return this.tagId ? `tag-${this.tagId}` : "tag_all";
  }

  modifyComponentForRow() {
    return "tag-row";
  }

  @computed("tagId")
  get shortcuts() {
    const shortcuts = [];

    if (this.tagId) {
      shortcuts.push({
        id: ALL_TAGS_ID,
        name: i18n("tagging.selector_remove_filter"),
      });
    }

    if (this.tagId !== NONE_TAG) {
      shortcuts.push({
        id: NO_TAG_ID,
        name: i18n("tagging.selector_no_tags"),
      });
    }

    // If there is a single shortcut, we can have a single "remove filter"
    // option
    if (shortcuts.length === 1 && shortcuts[0].id === ALL_TAGS_ID) {
      shortcuts[0].name = i18n("tagging.selector_remove_filter");
    }

    return shortcuts;
  }

  @computed("currentCategory", "site.category_top_tags.[]", "site.top_tags.[]")
  get topTags() {
    if (this.currentCategory && this.site.category_top_tags) {
      return this.site.category_top_tags || [];
    }

    return this.site.top_tags || [];
  }

  @computed("topTags.[]", "shortcuts.[]")
  get content() {
    const topTags = this.topTags.slice(0, this.maxTagsInFilterList);
    if (this.sortTagsAlphabetically && topTags) {
      return this.shortcuts.concat(topTags.sort());
    } else {
      return this.shortcuts.concat(makeArray(topTags));
    }
  }

  search(filter) {
    if (filter) {
      const data = {
        q: filter,
        limit: this.maxTagSearchResults,
      };

      return this.searchTags("/tags/filter/search", data, this._transformJson);
    } else {
      return (this.content || []).map((tag) => {
        if (tag.id && tag.name) {
          return tag;
        }
        return this.defaultItem(tag, tag);
      });
    }
  }

  _transformJson(context, json) {
    return json.results
      .sort((a, b) => a.id > b.id)
      .map((r) => {
        const content = context.defaultItem(r.id, r.text);
        content.targetTagId = r.target_tag || r.id;
        if (!context.currentCategory) {
          content.count = r.count;
        }
        content.pmCount = r.pm_count;
        return content;
      });
  }

  @action
  onChange(tagId, tag) {
    if (tagId === NO_TAG_ID) {
      tagId = NONE_TAG;
    } else if (tagId === ALL_TAGS_ID) {
      tagId = null;
    } else if (tag && tag.targetTagId) {
      tagId = tag.targetTagId;
    }

    DiscourseURL.routeToUrl(
      getCategoryAndTagUrl(this.currentCategory, !this.noSubcategories, tagId)
    );
  }
}
