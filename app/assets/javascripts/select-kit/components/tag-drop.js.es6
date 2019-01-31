import ComboBoxComponent from "select-kit/components/combo-box";
import DiscourseURL from "discourse/lib/url";
import TagsMixin from "select-kit/mixins/tags";
import { default as computed } from "ember-addons/ember-computed-decorators";
const { isEmpty, run } = Ember;

export default ComboBoxComponent.extend(TagsMixin, {
  pluginApiIdentifiers: ["tag-drop"],
  classNameBindings: ["categoryStyle", "tagClass"],
  classNames: "tag-drop",
  verticalOffset: 3,
  value: Ember.computed.alias("tagId"),
  headerComponent: "tag-drop/tag-drop-header",
  rowComponent: "tag-drop/tag-drop-row",
  allowAutoSelectFirst: false,
  tagName: "li",
  showFilterByTag: Ember.computed.alias("siteSettings.show_filter_by_tag"),
  currentCategory: Ember.computed.or("secondCategory", "firstCategory"),
  tagId: null,
  categoryStyle: Ember.computed.alias("siteSettings.category_style"),
  mutateAttributes() {},
  fullWidthOnMobile: true,
  caretDownIcon: "caret-right",
  caretUpIcon: "caret-down",
  allowContentReplacement: true,
  isAsync: true,

  @computed("tagId")
  noTagsSelected() {
    return this.get("tagId") === "none";
  },

  @computed("showFilterByTag", "content")
  isHidden(showFilterByTag, content) {
    if (showFilterByTag && !isEmpty(content)) return false;
    return true;
  },

  @computed("content")
  filterable(content) {
    return content && content.length >= 15;
  },

  computeHeaderContent() {
    let content = this._super(...arguments);

    if (!content.value) {
      if (this.get("tagId")) {
        content.title = this.get("tagId");
      } else if (this.get("noTagsSelected")) {
        content.title = this.get("noTagsLabel");
      } else {
        content.title = this.get("allTagsLabel");
      }
    } else {
      content.title = content.value;
    }

    return content;
  },

  @computed("tagId")
  tagClass(tagId) {
    return tagId ? `tag-${tagId}` : "tag_all";
  },

  @computed("firstCategory", "secondCategory")
  allTagsUrl() {
    if (this.get("currentCategory")) {
      return Discourse.getURL(this.get("currentCategory.url") + "?allTags=1");
    } else {
      return Discourse.getURL("/");
    }
  },

  @computed("firstCategory", "secondCategory")
  noTagsUrl() {
    var url = "/tags";
    if (this.get("currentCategory")) {
      url += this.get("currentCategory.url");
    }
    return Discourse.getURL(`${url}/none`);
  },

  @computed("tag")
  allTagsLabel() {
    return I18n.t("tagging.selector_all_tags");
  },

  @computed("tag")
  noTagsLabel() {
    return I18n.t("tagging.selector_no_tags");
  },

  @computed("tagId", "allTagsLabel", "noTagsLabel")
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

  @computed("site.top_tags", "shortcuts")
  content(topTags, shortcuts) {
    if (this.siteSettings.tags_sort_alphabetically && topTags) {
      return shortcuts.concat(topTags.sort());
    } else {
      return shortcuts.concat(Ember.makeArray(topTags));
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
    return results;
  },

  actions: {
    onSelect(tagId) {
      let url;

      if (tagId === "all-tags") {
        url = Discourse.getURL(this.get("allTagsUrl"));
      } else if (tagId === "no-tags") {
        url = Discourse.getURL(this.get("noTagsUrl"));
      } else {
        url = "/tags";
        if (this.get("currentCategory")) {
          url += this.get("currentCategory.url");
        }
        url = Discourse.getURL(`${url}/${tagId.toLowerCase()}`);
      }

      DiscourseURL.routeTo(url);
    },

    onExpand() {
      if (isEmpty(this.get("asyncContent"))) {
        this.set("asyncContent", this.get("content"));
      }
    },

    onFilter(filter) {
      if (isEmpty(filter)) {
        this.set("asyncContent", this.get("content"));
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
