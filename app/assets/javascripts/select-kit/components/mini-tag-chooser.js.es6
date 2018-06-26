import ComboBox from "select-kit/components/combo-box";
import Tags from "select-kit/mixins/tags";
import { default as computed } from "ember-addons/ember-computed-decorators";
import renderTag from "discourse/lib/render-tag";
import { escapeExpression } from "discourse/lib/utilities";
const { get, isEmpty, run, makeArray } = Ember;

export default ComboBox.extend(Tags, {
  allowContentReplacement: true,
  headerComponent: "mini-tag-chooser/mini-tag-chooser-header",
  pluginApiIdentifiers: ["mini-tag-chooser"],
  attributeBindings: ["categoryId"],
  classNames: ["mini-tag-chooser"],
  classNameBindings: ["noTags"],
  verticalOffset: 3,
  filterable: true,
  noTags: Ember.computed.empty("selection"),
  allowAny: true,
  caretUpIcon: Ember.computed.alias("caretIcon"),
  caretDownIcon: Ember.computed.alias("caretIcon"),
  isAsync: true,
  fullWidthOnMobile: true,

  init() {
    this._super();

    this.set("termMatchesForbidden", false);
    this.selectionSelector = ".selected-tag";

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
        this.get("limit") ||
          this.get("maximum") ||
          this.get("siteSettings.max_tags_per_topic")
      )
    );
  },

  @computed("hasReachedMaximum")
  caretIcon(hasReachedMaximum) {
    return hasReachedMaximum ? null : "plus fa-fw";
  },

  @computed("tags")
  selection(tags) {
    return makeArray(tags).map(c => this.computeContentItem(c));
  },

  filterComputedContent(computedContent) {
    return computedContent;
  },

  didRender() {
    this._super();

    this.$(".select-kit-body").on(
      "click.mini-tag-chooser",
      ".selected-tag",
      event => {
        event.stopImmediatePropagation();
        this.destroyTags(
          this.computeContentItem($(event.target).attr("data-value"))
        );
      }
    );

    this.$(".select-kit-header").on(
      "focus.mini-tag-chooser",
      ".selected-name",
      event => {
        event.stopImmediatePropagation();
        this.focus(event);
      }
    );
  },

  willDestroyElement() {
    this._super();

    this.$(".select-kit-body").off("click.mini-tag-chooser");
    this.$(".select-kit-header").off("focus.mini-tag-chooser");
  },

  // we are directly mutatings tags to define the current selection
  mutateValue() {},

  didPressTab(event) {
    if (this.get("isLoading")) {
      this._destroyEvent(event);
      return false;
    }

    if (isEmpty(this.get("filter")) && !this.get("highlighted")) {
      this.$header().focus();
      this.close(event);
      return true;
    }

    if (this.get("highlighted") && this.get("isExpanded")) {
      this._destroyEvent(event);
      this.focus();
      this.select(this.get("highlighted"));
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
            ${tag}
          </button>
        `;
      });

      return `<div class="selected-tags">${output}</div>`;
    }
  },

  computeHeaderContent() {
    let content = this._super();

    const joinedTags = this.get("selection")
      .map(s => Ember.get(s, "value"))
      .join(", ");

    if (isEmpty(this.get("selection"))) {
      content.label = I18n.t("tagging.choose_for_topic");
    } else {
      content.label = joinedTags;
    }

    if (!this.get("hasReachedMinimum") && isEmpty(this.get("selection"))) {
      const key =
        this.get("minimumLabel") || "select_kit.min_content_not_reached";
      const label = I18n.t(key, { count: this.get("minimum") });
      content.title = content.name = content.label = label;
    }

    content.title = content.name = content.value = joinedTags;

    return content;
  },

  _prepareSearch(query) {
    const data = {
      q: query,
      limit: this.get("siteSettings.max_tag_search_results"),
      categoryId: this.get("categoryId")
    };

    if (this.get("selection")) {
      data.selected_tags = this.get("selection")
        .map(s => Ember.get(s, "value"))
        .slice(0, 100);
    }

    if (!this.get("everyTag")) data.filterForInput = true;

    this.searchTags("/tags/filter/search", data, this._transformJson);
  },

  _transformJson(context, json) {
    let results = json.results;

    context.set("termMatchesForbidden", json.forbidden ? true : false);

    if (context.get("siteSettings.tags_sort_alphabetically")) {
      results = results.sort((a, b) => a.id > b.id);
    }

    results = results.filter(r => !context.get("selection").includes(r.id));

    results = results.map(result => {
      return { id: result.text, name: result.text, count: result.count };
    });

    // if forbidden we probably have an existing tag which is not in the list of
    // returned tags, so we manually add it at the top
    if (json.forbidden) {
      results.unshift({ id: json.forbidden, name: json.forbidden, count: 0 });
    }

    return results;
  },

  destroyTags(tags) {
    tags = Ember.makeArray(tags).map(c => get(c, "value"));

    // work around usage with buffered proxy
    // it does not listen on array changes, similar hack already on select
    // TODO: FIX buffered-proxy.js to support arrays
    this.get("tags").removeObjects(tags);
    this.set("tags", this.get("tags").slice(0));

    this.set(
      "searchDebounce",
      run.debounce(this, this._prepareSearch, this.get("filter"), 350)
    );
  },

  didDeselect(tags) {
    this.destroyTags(tags);
  },

  actions: {
    onSelect(tag) {
      this.set("tags", makeArray(this.get("tags")).concat(tag));
      this._prepareSearch(this.get("filter"));
      this.autoHighlight();
    },

    onExpand() {
      if (isEmpty(this.get("collectionComputedContent"))) {
        this.set(
          "searchDebounce",
          run.debounce(this, this._prepareSearch, this.get("filter"), 350)
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
