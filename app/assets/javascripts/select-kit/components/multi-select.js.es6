import SelectKitComponent from "select-kit/components/select-kit";
import computed from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";
const { get, isNone, isEmpty, makeArray } = Ember;
import {
  applyOnSelectPluginApiCallbacks
} from "select-kit/mixins/plugin-api";

export default SelectKitComponent.extend({
  pluginApiIdentifiers: ["multi-select"],
  layoutName: "select-kit/templates/components/multi-select",
  classNames: "multi-select",
  headerComponent: "multi-select/multi-select-header",
  headerText: "select_kit.default_header_text",
  allowAny: true,
  allowInitialValueMutation: false,
  autoFilterable: true,
  selectedNameComponent: "multi-select/selected-name",
  filterIcon: null,

  init() {
    this._super();

    this.set("computedValues", []);
    if (isNone(this.get("values"))) { this.set("values", []); }

    this.set("headerComponentOptions", Ember.Object.create({
      selectedNameComponent: this.get("selectedNameComponent")
    }));
  },

  @on("didRender")
  _setChoicesMaxWidth() {
    const width = this.$body().outerWidth(false);
    this.$(".choices").css({ maxWidth: width, width });
  },

  @on("didReceiveAttrs")
  _compute() {
    Ember.run.scheduleOnce("afterRender", () => {
      this.willComputeAttributes();
      let content = this.get("content") || [];
      let asyncContent = this.get("asyncContent") || [];
      content = this.willComputeContent(content);
      asyncContent = this.willComputeAsyncContent(asyncContent);
      let values = this._beforeWillComputeValues(this.get("values"));
      content = this.computeContent(content);
      asyncContent = this.computeAsyncContent(asyncContent);
      content = this._beforeDidComputeContent(content);
      asyncContent = this._beforeDidComputeAsyncContent(asyncContent);
      values = this.willComputeValues(values);
      values = this.computeValues(values);
      values = this._beforeDidComputeValues(values);
      this._setHeaderComputedContent();
      this._setCollectionHeaderComputedContent();
      this.didComputeContent(content);
      this.didComputeAsyncContent(asyncContent);
      this.didComputeValues(values);
      this.didComputeAttributes();
    });
  },

  @computed("filter", "shouldDisplayCreateRow")
  createRowComputedContent(filter, shouldDisplayCreateRow) {
    if (shouldDisplayCreateRow === true) {
      let content = this.createContentFromInput(filter);
      return this.computeContentItem(content, { created: true });
    }
  },

  @computed("filter", "computedValues")
  shouldDisplayCreateRow(filter, computedValues) {
    return this._super() && !computedValues.includes(filter);
  },

  @computed
  shouldDisplayFilter() { return true; },

  _beforeWillComputeValues(values) {
    return values.map(v => this._castInteger(v === "" ? null : v));
  },
  willComputeValues(values) { return values; },
  computeValues(values) { return values; },
  _beforeDidComputeValues(values) {
    this.setProperties({ computedValues: values });
    return values;
  },
  didComputeValues(values) { return values; },

  mutateAttributes() {
    if (this.get("isDestroyed") || this.get("isDestroying")) return;

    Ember.run.next(() => {
      this.mutateContent(this.get("computedContent"));
      this.mutateValues(this.get("computedValues"));
      this._setCollectionHeaderComputedContent();
      this._setHeaderComputedContent();
    });
  },
  mutateValues(computedValues) {
    this.set("values", computedValues);
  },
  mutateContent() { },

  filterComputedContent(computedContent, computedValues, filter) {
    const lowerFilter = filter.toLowerCase();
    return computedContent.filter(c => {
      return get(c, "name").toLowerCase().indexOf(lowerFilter) > -1;
    });
  },

  @computed("computedAsyncContent.[]", "computedValues.[]")
  filteredAsyncComputedContent(computedAsyncContent, computedValues) {
    computedAsyncContent = computedAsyncContent.filter(c => {
      return !computedValues.includes(get(c, "value"));
    });

    if (this.get("limitMatches")) {
      return computedAsyncContent.slice(0, this.get("limitMatches"));
    }

    return computedAsyncContent;
  },

  @computed("computedContent.[]", "computedValues.[]", "filter")
  filteredComputedContent(computedContent, computedValues, filter) {
    computedContent = computedContent.filter(c => {
      return !computedValues.includes(get(c, "value"));
    });

    if (this.get("shouldFilter")) {
      computedContent = this.filterComputedContent(computedContent, computedValues, filter);
    }

    if (this.get("limitMatches")) {
      return computedContent.slice(0, this.get("limitMatches"));
    }

    return computedContent;
  },

  baseHeaderComputedContent() {
    return {
      title: this.get("title"),
      selectedComputedContents: this.get("selectedComputedContents")
    };
  },

  @computed("filter")
  templateForCreateRow() {
    return (rowComponent) => {
      return I18n.t("select_kit.create", { content: rowComponent.get("computedContent.name")});
    };
  },

  @computed("limit", "computedValues.[]")
  limitReached(limit, computedValues) {
    if (!limit) return false;
    return computedValues.length >= limit;
  },

  validateSelect() {
    return this._super() && !this.get("limitReached");
  },

  didPressBackspace(event) {
    this.expand(event);
    this.keyDown(event);
    this._destroyEvent(event);
  },

  didPressEscape(event) {
    const $highlighted = this.$(".selected-name.is-highlighted");
    if ($highlighted.length > 0) {
      $highlighted.removeClass("is-highlighted");
    }

    this._super(event);
  },

  keyDown(event) {
    if (!isEmpty(this.get("filter"))) return;

    const keyCode = event.keyCode || event.which;
    const $filterInput = this.$filterInput();

    // select all choices
    if (this.get("hasSelection") && event.metaKey === true && keyCode === 65) {
      this.$(".choices .selected-name:not(.is-locked)").addClass("is-highlighted");
      return false;
    }

    // clear selection when multiple
    if (this.$(".selected-name.is-highlighted").length >= 1 && keyCode === this.keys.BACKSPACE) {
      const highlightedComputedContents = [];
      $.each(this.$(".selected-name.is-highlighted"), (i, el) => {
        const computedContent = this._findComputedContentItemByGuid($(el).attr("data-guid"));
        if (!Ember.isNone(computedContent)) { highlightedComputedContents.push(computedContent); }
      });
      this.send("deselect", highlightedComputedContents);
      return;
    }

    // try to remove last item from the list
    if (keyCode === this.keys.BACKSPACE) {
      let $lastSelectedValue = $(this.$(".choices .selected-name:not(.is-locked)").last());

      if ($lastSelectedValue.length === 0) { return; }

      if ($filterInput.not(":visible") && $lastSelectedValue.length > 0) {
        $lastSelectedValue.trigger("backspace");
        return false;
      }

      if ($filterInput.val() === "") {
        if ($filterInput.is(":focus")) {
          if ($lastSelectedValue.length > 0) { $lastSelectedValue.trigger("backspace"); }
        } else {
          if ($lastSelectedValue.length > 0) {
            $lastSelectedValue.trigger("backspace");
          } else {
            $filterInput.focus();
          }
        }
      }
    }
  },

  @computed("computedValues.[]", "computedContent.[]")
  selectedComputedContents(computedValues, computedContent) {
    const selected = [];

    computedValues.forEach(v => {
      const value = computedContent.findBy("value", v);
      if (value) selected.push(value);
    });

    return selected;
  },

  @computed("selectedComputedContents.[]")
  hasSelection(selectedComputedContents) { return !Ember.isEmpty(selectedComputedContents); },

  autoHighlight() {
    Ember.run.schedule("afterRender", () => {
      if (!this.get("isExpanded")) return;
      if (!this.get("renderedBodyOnce")) return;
      if (!isNone(this.get("highlightedValue"))) return;

      if (isEmpty(this.get("collectionComputedContent"))) {
        if (this.get("createRowComputedContent")) {
          this.send("highlight", this.get("createRowComputedContent"));
        } else if (this.get("noneRowComputedContent") && this.get("hasSelection")) {
          this.send("highlight", this.get("noneRowComputedContent"));
        }
      } else {
        this.send("highlight", this.get("collectionComputedContent.firstObject"));
      }
    });
  },

  didSelect() {
    this.focusFilterOrHeader();
    this.autoHighlight();

    applyOnSelectPluginApiCallbacks(
      this.get("pluginApiIdentifiers"),
      this.get("computedValue"),
      this
    );

    this._boundaryActionHandler("onSelect", this.get("computedValue"));
  },

  willDeselect() {
    this.clearFilter();
    this.set("highlightedValue", null);
  },

  didDeselect(rowComputedContentItems) {
    this.focusFilterOrHeader();
    this.autoHighlight();
    this._boundaryActionHandler("onDeselect", rowComputedContentItems);
  },

  actions: {
    clearSelection() {
      this.send("deselect", this.get("selectedComputedContents"));
      this._boundaryActionHandler("onClearSelection");
    },

    create(computedContentItem) {
      if (!this.get("computedValues").includes(computedContentItem.value) &&
          this.validateCreate(computedContentItem.value)) {
        this.get("computedContent").pushObject(computedContentItem);
        this._boundaryActionHandler("onCreate");
        this.send("select", computedContentItem);
      } else {
        this._boundaryActionHandler("onCreateFailure");
      }
    },

    select(computedContentItem) {
      this.willSelect(computedContentItem);

      if (this.validateSelect(computedContentItem)) {
        this.get("computedValues").pushObject(computedContentItem.value);
        Ember.run.next(() => this.mutateAttributes());
        Ember.run.schedule("afterRender", () => this.didSelect(computedContentItem));
      } else {
        this._boundaryActionHandler("onSelectFailure");
      }
    },

    deselect(rowComputedContentItems) {
      rowComputedContentItems = Ember.makeArray(rowComputedContentItems);
      const generatedComputedContents = this._filterRemovableComputedContents(makeArray(rowComputedContentItems));
      this.willDeselect(rowComputedContentItems);
      this.get("computedValues").removeObjects(rowComputedContentItems.map(r => r.value));
      this.get("computedContent").removeObjects(generatedComputedContents);
      Ember.run.next(() => this.mutateAttributes());
      Ember.run.schedule("afterRender", () => this.didDeselect(rowComputedContentItems));
    }
  }
});
