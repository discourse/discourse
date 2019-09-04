import Category from "discourse/models/category";
import ComboBox from "select-kit/components/combo-box";
import TagsMixin from "select-kit/mixins/tags";
import { default as computed } from "ember-addons/ember-computed-decorators";
import renderTag from "discourse/lib/render-tag";
import { escapeExpression } from "discourse/lib/utilities";
import { iconHTML } from "discourse-common/lib/icon-library";
const { get, isEmpty, run, makeArray } = Ember;

export default ComboBox.extend(TagsMixin, {
  allowContentReplacement: true,
  headerComponent: "mini-tag-chooser/mini-tag-chooser-header",
  pluginApiIdentifiers: ["mini-tag-chooser"],
  attributeBindings: ["categoryId"],
  classNames: ["mini-tag-chooser"],
  classNameBindings: ["noTags"],
  verticalOffset: 3,
  filterable: true,
  noTags: Ember.computed.empty("selection"),
  allowCreate: null,
  allowAny: Ember.computed.alias("allowCreate"),
  caretUpIcon: Ember.computed.alias("caretIcon"),
  caretDownIcon: Ember.computed.alias("caretIcon"),
  isAsync: true,
  fullWidthOnMobile: true,

  init() {
    this._super(...arguments);

    this.set("termMatchesForbidden", false);
    this.selectionSelector = ".selected-tag";

    if (this.allowCreate !== false) {
      this.set("allowCreate", this.site.get("can_create_tag"));
    }

    this.set("templateForRow", rowComponent => {
      const tag = rowComponent.get("computedContent");
      return renderTag(get(tag, "value"), {
        count: get(tag, "originalContent.count"),
        noHref: true
      });
    });

    this.set(
      "maximum",
      parseInt(
        this.limit ||
          this.maximum ||
          this.get("siteSettings.max_tags_per_topic")
      )
    );
  },

  @computed(
    "computedValue",
    "filter",
    "collectionComputedContent.[]",
    "hasReachedMaximum",
    "hasReachedMinimum",
    "categoryId"
  )
  shouldDisplayCreateRow() {
    if (this.categoryId) {
      const category = Category.findById(this.categoryId);
      if (
        (category.allowed_tags && category.allowed_tags.length > 0) ||
        (category.allowed_tag_groups && category.allowed_tag_groups.length > 0)
      ) {
        return category.allow_global_tags && this._super(...arguments);
      }
    }
    return this._super(...arguments);
  },

  didInsertElement() {
    this._super(...arguments);

    $(this.element.querySelector(".select-kit-body")).on(
      "mousedown touchstart",
      ".selected-tag",
      event => {
        const $button = $(event.target).closest(".selected-tag");
        this._destroyEvent(event);
        this.destroyTags(this.computeContentItem($button.attr("data-value")));
      }
    );
  },

  willDestroyElement() {
    this._super(...arguments);

    $(this.element.querySelector(".select-kit-body")).off(
      "mousedown touchstart"
    );
  },

  @computed("hasReachedMaximum")
  caretIcon(hasReachedMaximum) {
    return hasReachedMaximum ? null : "plus";
  },

  @computed("tags")
  selection(tags) {
    return makeArray(tags).map(c => this.computeContentItem(c));
  },

  filterComputedContent(computedContent) {
    return computedContent;
  },

  // we are directly mutatings tags to define the current selection
  mutateValue() {},

  didPressTab(event) {
    if (this.isLoading) {
      this._destroyEvent(event);
      return false;
    }

    if (isEmpty(this.filter) && !this.highlighted) {
      this.$header().focus();
      this.close(event);
      return true;
    }

    if (this.highlighted && this.isExpanded) {
      this._destroyEvent(event);
      this.focus();
      this.select(this.highlighted);
      return false;
    } else {
      this.close(event);
    }

    return true;
  },

  @computed("tags.[]", "filter", "highlightedSelection.[]")
  collectionHeader(tags, filter, highlightedSelection) {
    if (!isEmpty(tags)) {
      let output = "";

      // if we have more than x tags we will also filter the selection
      if (tags.length >= 20) {
        tags = tags.filter(t => t.indexOf(filter) >= 0);
      }

      tags.map(tag => {
        tag = escapeExpression(tag);
        const isHighlighted = highlightedSelection
          .map(s => get(s, "value"))
          .includes(tag);
        output += `
          <button aria-label="${tag}" title="${tag}" class="selected-tag ${
          isHighlighted ? "is-highlighted" : ""
        }" data-value="${tag}">
            ${tag} ${iconHTML("times")}
          </button>
        `;
      });

      return `<div class="selected-tags">${output}</div>`;
    }
  },

  computeHeaderContent() {
    let content = this._super(...arguments);

    const joinedTags = this.selection
      .map(s => Ember.get(s, "value"))
      .join(", ");

    if (isEmpty(this.selection)) {
      content.label = I18n.t("tagging.choose_for_topic");
    } else {
      content.label = joinedTags;
    }

    if (!this.hasReachedMinimum && isEmpty(this.selection)) {
      const key = this.minimumLabel || "select_kit.min_content_not_reached";
      const label = I18n.t(key, { count: this.minimum });
      content.title = content.name = content.label = label;
    }

    content.title = content.name = content.value = joinedTags;

    return content;
  },

  _prepareSearch(query, options) {
    const data = {
      q: query,
      limit: this.get("siteSettings.max_tag_search_results"),
      categoryId: this.categoryId
    };

    if (this.selection) {
      data.selected_tags = this.selection
        .map(s => Ember.get(s, "value"))
        .slice(0, 100);
    }

    if (!this.everyTag) data.filterForInput = true;

    this.searchTags("/tags/filter/search", data, this._transformJson, options);
  },

  _transformJson(context, json) {
    let results = json.results;

    context.set("termMatchesForbidden", json.forbidden ? true : false);
    context.set("termMatchErrorMessage", json.forbidden_message);

    if (context.get("siteSettings.tags_sort_alphabetically")) {
      results = results.sort((a, b) => a.id > b.id);
    }

    results = results.filter(r => !context.get("selection").includes(r.id));

    results = results.map(result => {
      return { id: result.text, name: result.text, count: result.count };
    });

    return results;
  },

  destroyTags(tags) {
    tags = Ember.makeArray(tags).map(c => get(c, "value"));

    // work around usage with buffered proxy
    // it does not listen on array changes, similar hack already on select
    // TODO: FIX buffered-proxy.js to support arrays
    this.tags.removeObjects(tags);
    this.set("tags", this.tags.slice(0));
    this._tagsChanged();

    this.set(
      "searchDebounce",
      run.debounce(this, this._prepareSearch, this.filter, 350)
    );
  },

  didDeselect(tags) {
    this.destroyTags(tags);
  },

  didUpdateAttrs() {
    this._super(...arguments);

    this._prepareSearch(this.filter, { background: true });
  },

  _tagsChanged() {
    if (this.attrs.onChangeTags) {
      this.attrs.onChangeTags({ target: { value: this.tags } });
    }
  },

  actions: {
    onSelect(tag) {
      this.set("tags", makeArray(this.tags).concat(tag));
      this._tagsChanged();

      this._prepareSearch(this.filter);
      this.autoHighlight();
    },

    onExpand() {
      if (isEmpty(this.collectionComputedContent)) {
        this.set(
          "searchDebounce",
          run.debounce(this, this._prepareSearch, this.filter, 350)
        );
      }
    },

    onFilter(filter) {
      // we start loading right away so we avoid updating createRow multiple times
      this.startLoading();

      filter = isEmpty(filter) ? null : filter;
      this.set(
        "searchDebounce",
        run.debounce(this, this._prepareSearch, filter, 350)
      );
    }
  }
});
