import { computed } from "@ember/object";
import { alias } from "@ember/object/computed";
import { makeArray } from "discourse-common/lib/helpers";
import ComboBoxComponent from "select-kit/components/combo-box";
import DiscourseURL from "discourse/lib/url";
import TagsMixin from "select-kit/mixins/tags";
import { default as discourseComputed } from "discourse-common/utils/decorators";
const { isEmpty, run } = Ember;
import Category from "discourse/models/category";
import deprecated from "discourse-common/lib/deprecated";

export default ComboBoxComponent.extend(TagsMixin, {
  pluginApiIdentifiers: ["tag-drop"],
  classNameBindings: ["categoryStyle", "tagClass"],
  classNames: "tag-drop",
  verticalOffset: 3,
  value: alias("tagId"),
  headerComponent: "tag-drop/tag-drop-header",
  allowAutoSelectFirst: false,
  tagName: "li",
  showFilterByTag: alias("siteSettings.show_filter_by_tag"),
  tagId: null,
  categoryStyle: alias("siteSettings.category_style"),
  mutateAttributes() {},
  fullWidthOnMobile: true,
  caretDownIcon: "caret-right",
  caretUpIcon: "caret-down",
  allowContentReplacement: true,
  isAsync: true,

  currentCategory: computed("secondCategory", "firstCategory", {
    set(key, value) {
      this.currentCategoryRaw = value;
      return value;
    },

    get() {
      if (this.currentCategoryRaw) {
        return this.currentCategoryRaw;
      }

      const result = this.secondCategory || this.firstCategory;
      if (result) {
        deprecated(
          "Setting firstCategory and secondCategory on tag-drop directly is deprecated. Please use currentCategory instead."
        );
        return result;
      }
    }
  }),

  @discourseComputed("tagId")
  noTagsSelected() {
    return this.tagId === "none";
  },

  @discourseComputed("showFilterByTag", "content")
  isHidden(showFilterByTag, content) {
    if (showFilterByTag && !isEmpty(content)) return false;
    return true;
  },

  @discourseComputed("content")
  filterable(content) {
    return content && content.length >= 15;
  },

  computeHeaderContent() {
    let content = this._super(...arguments);

    if (!content.value) {
      if (this.tagId) {
        if (this.tagId === "none") {
          content.title = this.noTagsLabel;
        } else {
          content.title = this.tagId;
        }
      } else if (this.noTagsSelected) {
        content.title = this.noTagsLabel;
      } else {
        content.title = this.allTagsLabel;
      }
    } else {
      content.title = content.value;
    }

    return content;
  },

  @discourseComputed("tagId")
  tagClass(tagId) {
    return tagId ? `tag-${tagId}` : "tag_all";
  },

  @discourseComputed("currentCategory")
  allTagsUrl() {
    if (this.currentCategory) {
      return Discourse.getURL(this.get("currentCategory.url") + "?allTags=1");
    } else {
      return Discourse.getURL("/");
    }
  },

  @discourseComputed("currentCategory")
  noTagsUrl(currentCategory) {
    let url = "/tags";

    if (currentCategory) {
      url += `/c/${Category.slugFor(currentCategory)}/${currentCategory.id}`;
    }

    return Discourse.getURL(`${url}/none`);
  },

  @discourseComputed("tag")
  allTagsLabel() {
    return I18n.t("tagging.selector_all_tags");
  },

  @discourseComputed("tag")
  noTagsLabel() {
    return I18n.t("tagging.selector_no_tags");
  },

  @discourseComputed("tagId", "allTagsLabel", "noTagsLabel")
  shortcuts(tagId, allTagsLabel, noTagsLabel) {
    const shortcuts = [];

    if (tagId !== "none") {
      shortcuts.push({
        name: noTagsLabel,
        __sk_row_type: "noopRow",
        id: "no-tags"
      });
    }

    if (tagId) {
      shortcuts.push({
        name: allTagsLabel,
        __sk_row_type: "noopRow",
        id: "all-tags"
      });
    }

    return shortcuts;
  },

  @discourseComputed("site.top_tags", "shortcuts")
  content(topTags, shortcuts) {
    if (this.siteSettings.tags_sort_alphabetically && topTags) {
      return shortcuts.concat(topTags.sort());
    } else {
      return shortcuts.concat(makeArray(topTags));
    }
  },

  _prepareSearch(query) {
    const data = {
      q: query,
      limit: this.get("siteSettings.max_tag_search_results")
    };

    this.searchTags("/tags/filter/search", data, this._transformJson);
  },

  _transformJson(context, json) {
    let results = json.results;
    results = results.sort((a, b) => a.id > b.id);

    return results.map(r => {
      return {
        id: r.id,
        name: r.text,
        targetTagId: r.target_tag || r.id
      };
    });
  },

  actions: {
    onSelect(tagId, tag) {
      let url;

      if (tagId === "all-tags") {
        url = Discourse.getURL(this.allTagsUrl);
      } else if (tagId === "no-tags") {
        url = Discourse.getURL(this.noTagsUrl);
      } else {
        url = "/tags";

        if (this.currentCategory) {
          url += `/c/${Category.slugFor(this.currentCategory)}/${
            this.currentCategory.id
          }`;
        }

        if (tag && tag.targetTagId) {
          url += `/${tag.targetTagId.toLowerCase()}`;
        } else {
          url += `/${tagId.toLowerCase()}`;
        }
        url = Discourse.getURL(url);
      }

      DiscourseURL.routeTo(url);
    },

    onExpand() {
      if (isEmpty(this.asyncContent)) {
        this.set("asyncContent", this.content);
      }
    },

    onFilter(filter) {
      if (isEmpty(filter)) {
        this.set("asyncContent", this.content);
        return;
      }

      this.startLoading();

      this.set(
        "searchDebounce",
        run.debounce(this, this._prepareSearch, filter, 350)
      );
    }
  }
});
