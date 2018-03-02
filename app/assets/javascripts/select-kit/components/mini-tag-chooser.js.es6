import ComboBox from "select-kit/components/combo-box";
import Tags from "select-kit/mixins/tags";
import { default as computed } from "ember-addons/ember-computed-decorators";
import renderTag from "discourse/lib/render-tag";
const { get, isEmpty, run, makeArray } = Ember;

export default ComboBox.extend(Tags, {
  allowContentReplacement: true,
  pluginApiIdentifiers: ["mini-tag-chooser"],
  attributeBindings: ["categoryId"],
  classNames: ["mini-tag-chooser"],
  classNameBindings: ["noTags"],
  verticalOffset: 3,
  filterable: true,
  noTags: Ember.computed.empty("selectedTags"),
  allowAny: true,
  caretUpIcon: Ember.computed.alias("caretIcon"),
  caretDownIcon: Ember.computed.alias("caretIcon"),
  isAsync: true,

  init() {
    this._super();

    this.set("termMatchesForbidden", false);

    this.set("templateForRow", (rowComponent) => {
      const tag = rowComponent.get("computedContent");
      return renderTag(get(tag, "value"), {
        count: get(tag, "originalContent.count"),
        noHref: true
      });
    });

    this.set("limit", parseInt(this.get("limit") || this.get("siteSettings.max_tags_per_topic")));
  },

  @computed("limitReached")
  caretIcon(limitReached) {
    return limitReached ? null : "plus";
  },

  @computed("selectedTags.[]", "limit")
  limitReached(selectedTags, limit) {
    if (selectedTags.length >= limit) {
      return true;
    }

    return false;
  },

  @computed("tags")
  selectedTags(tags) {
    return makeArray(tags);
  },

  filterComputedContent(computedContent) {
    return computedContent;
  },

  didRender() {
    this._super();

    $(".select-kit-body").on("click.mini-tag-chooser", ".selected-tag", (event) => {
      event.stopImmediatePropagation();
      this.send("removeTag", $(event.target).attr("data-value"));
    });
  },

  willDestroyElement() {
    this._super();

    $(".select-kit-body").off("click.mini-tag-chooser");
  },

  didPressEscape(event) {
    const $lastSelectedTag = $(".selected-tag.selected:last");

    if ($lastSelectedTag && this.get("isExpanded")) {
      $lastSelectedTag.removeClass("selected");
      this._destroyEvent(event);
    } else {
      this._super(event);
    }
  },

  backspaceFromFilter(event) {
    this.didPressBackspace(event);
  },

  // we are relying on selectedTags and not on value
  // to define the current selection
  mutateValue() {},

  didPressBackspace() {
    if (!this.get("isExpanded")) {
      this.expand();
      return;
    }

    const $lastSelectedTag = $(".selected-tag:last");

    if (!isEmpty(this.get("filter"))) {
      $lastSelectedTag.removeClass("is-highlighted");
      return;
    }

    if (!$lastSelectedTag.length) return;

    if (!$lastSelectedTag.hasClass("is-highlighted")) {
      $lastSelectedTag.addClass("is-highlighted");
    } else {
      this.send("removeTag", $lastSelectedTag.attr("data-value"));
    }
  },

  @computed("tags.[]", "filter")
  collectionHeader(tags, filter) {
    if (!isEmpty(tags)) {
      let output = "";

      if (tags.length >= 20) {
        tags = tags.filter(t => t.indexOf(filter) >= 0);
      }

      tags.map((tag) => {
        output += `
          <button class="selected-tag" data-value="${tag}">
            ${tag}
          </button>
        `;
      });

      return `<div class="selected-tags">${output}</div>`;
    }
  },

  computeHeaderContent() {
    let content = this.baseHeaderComputedContent();
    const joinedTags = this.get("selectedTags").join(", ");

    if (isEmpty(this.get("selectedTags"))) {
      content.label = I18n.t("tagging.choose_for_topic");
    } else {
      content.label = joinedTags;
    }

    content.title = content.name = content.value = joinedTags;

    return content;
  },

  actions: {
    removeTag(tag) {
      let tags = this.get("selectedTags");
      delete tags[tags.indexOf(tag)];
      this.set("tags", tags.filter(t => t));
      this.set("searchDebounce", run.debounce(this, this.prepareSearch, this.get("filter"), 200));
    },

    onExpand() {
      if (isEmpty(this.get("collectionComputedContent"))) {
        this.set("searchDebounce", run.debounce(this, this.prepareSearch, this.get("filter"), 200));
      }
    },

    onFilter(filter) {
      filter = isEmpty(filter) ? null : filter;
      this.set("searchDebounce", run.debounce(this, this.prepareSearch, filter, 200));
    },

    onSelect(tag) {
      if (isEmpty(this.get("selectedTags"))) {
        this.set("tags", makeArray(tag));
      } else {
        this.set("tags", this.get("selectedTags").concat(tag));
      }

      this.set("searchDebounce", run.debounce(this, this.prepareSearch, this.get("filter"), 50));

      this.autoHighlight();
    }
  },

  prepareSearch(query) {
    const data = {
      q: query,
      limit: this.get("siteSettings.max_tag_search_results"),
      categoryId: this.get("categoryId")
    };
    if (this.get("selectedTags")) data.selected_tags = this.get("selectedTags").slice(0, 100);

    this.searchTags("/tags/filter/search", data, this._transformJson);
  },

  _transformJson(context, json) {
    let results = json.results;

    context.set("termMatchesForbidden", json.forbidden ? true : false);

    if (context.get("siteSettings.tags_sort_alphabetically")) {
      results = results.sort((a, b) => a.id > b.id);
    }

    results = results.filter(r => !context.get("selectedTags").includes(r.id));

    return results.map(result => {
      return { id: result.text, name: result.text, count: result.count };
    });
  }
});
