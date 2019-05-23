import SelectKitComponent from "select-kit/components/select-kit";
import computed from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";
const { get, isNone, isEmpty, makeArray, run } = Ember;
import {
  applyOnSelectPluginApiCallbacks,
  applyOnSelectNonePluginApiCallbacks
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
  filterComponent: "multi-select/multi-select-filter",
  computedValues: null,
  values: null,

  init() {
    this._super(...arguments);

    this.set("computedValues", []);

    if (isNone(this.values)) {
      this.set("values", []);
    }

    this.headerComponentOptions.setProperties({
      selectedNameComponent: this.selectedNameComponent
    });
  },

  @on("didRender")
  _setChoicesMaxWidth() {
    const width = this.$body().outerWidth(false);
    if (width > 0) {
      this.$(".choices").css({ maxWidth: width });
    }
  },

  @on("didUpdateAttrs", "init")
  _compute() {
    run.scheduleOnce("afterRender", () => {
      this.willComputeAttributes();
      let content = this.content || [];
      let asyncContent = this.asyncContent || [];
      content = this.willComputeContent(content);
      asyncContent = this.willComputeAsyncContent(asyncContent);
      let values = this._beforeWillComputeValues(this.values);
      content = this.computeContent(content);
      asyncContent = this.computeAsyncContent(asyncContent);
      content = this._beforeDidComputeContent(content);
      asyncContent = this._beforeDidComputeAsyncContent(asyncContent);
      values = this.willComputeValues(values);
      values = this.computeValues(values);
      values = this._beforeDidComputeValues(values);
      this.didComputeContent(content);
      this.didComputeAsyncContent(asyncContent);
      this.didComputeValues(values);
      this.didComputeAttributes();
    });
  },

  @computed("filter", "shouldDisplayCreateRow")
  createRowComputedContent(filter, shouldDisplayCreateRow) {
    if (shouldDisplayCreateRow) {
      let content = this.createContentFromInput(filter);
      return this.computeContentItem(content, { created: true });
    }
  },

  @computed("filter", "computedValues")
  shouldDisplayCreateRow(filter, computedValues) {
    return this._super() && !computedValues.includes(filter);
  },

  @computed
  shouldDisplayFilter() {
    return true;
  },

  _beforeWillComputeValues(values) {
    return values.map(v => this._cast(v === "" ? null : v));
  },
  willComputeValues(values) {
    return values;
  },
  computeValues(values) {
    return values;
  },
  _beforeDidComputeValues(values) {
    this.setProperties({ computedValues: values });
    return values;
  },
  didComputeValues(values) {
    return values;
  },

  mutateAttributes() {
    run.next(() => {
      if (this.isDestroyed || this.isDestroying) return;

      this.mutateContent(this.computedContent);
      this.mutateValues(this.computedValues);
    });
  },
  mutateValues(computedValues) {
    this.set("values", computedValues);
  },
  mutateContent() {},

  forceValues(values) {
    this.mutateValues(values);
    this._compute();
  },

  filterComputedContent(computedContent, computedValues, filter) {
    return computedContent.filter(c => {
      return this._normalize(get(c, "name")).indexOf(filter) > -1;
    });
  },

  @computed("computedAsyncContent.[]", "computedValues.[]")
  filteredAsyncComputedContent(computedAsyncContent, computedValues) {
    computedAsyncContent = computedAsyncContent.filter(c => {
      return !computedValues.includes(get(c, "value"));
    });

    if (this.limitMatches) {
      return computedAsyncContent.slice(0, this.limitMatches);
    }

    return computedAsyncContent;
  },

  @computed("computedContent.[]", "computedValues.[]", "filter")
  filteredComputedContent(computedContent, computedValues, filter) {
    computedContent = computedContent.filter(c => {
      return !computedValues.includes(get(c, "value"));
    });

    if (this.shouldFilter) {
      computedContent = this.filterComputedContent(
        computedContent,
        computedValues,
        this._normalize(filter)
      );
    }

    if (this.limitMatches) {
      return computedContent.slice(0, this.limitMatches);
    }

    return computedContent;
  },

  computeHeaderContent() {
    let content = {
      title: this.title,
      selection: this.selection
    };

    if (this.noneLabel) {
      if (!this.hasSelection) {
        content.title = content.name = content.label = I18n.t(
          this.noneLabel
        );
      }
    } else {
      if (!this.hasReachedMinimum) {
        const key =
          this.minimumLabel || "select_kit.min_content_not_reached";
        content.title = content.name = content.label = I18n.t(key, {
          count: this.minimum
        });
      }
    }

    return content;
  },

  @computed("filter")
  templateForCreateRow() {
    return rowComponent => {
      return I18n.t("select_kit.create", {
        content: rowComponent.get("computedContent.name")
      });
    };
  },

  validateSelect() {
    return this._super() && !this.hasReachedMaximum;
  },

  @computed(
    "computedValues.[]",
    "computedContent.[]",
    "computedAsyncContent.[]"
  )
  selection(computedValues, computedContent, computedAsyncContent) {
    const selected = [];
    const content = this.isAsync ? computedAsyncContent : computedContent;

    computedValues.forEach(v => {
      const value = content.findBy("value", v);
      if (value) selected.push(value);
    });

    return selected;
  },

  @computed("selection.[]")
  hasSelection(selection) {
    return !isEmpty(selection);
  },

  didPressTab(event) {
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

  autoHighlight() {
    run.schedule("afterRender", () => {
      if (!this.isExpanded) return;
      if (!this.renderedBodyOnce) return;
      if (this.highlighted) return;

      if (isEmpty(this.collectionComputedContent)) {
        if (this.createRowComputedContent) {
          this.highlight(this.createRowComputedContent);
        } else if (
          this.noneRowComputedContent &&
          this.hasSelection
        ) {
          this.highlight(this.noneRowComputedContent);
        }
      } else {
        this.highlight(this.get("collectionComputedContent.firstObject"));
      }
    });
  },

  select(computedContentItem) {
    if (
      !computedContentItem ||
      computedContentItem.__sk_row_type === "noneRow"
    ) {
      applyOnSelectNonePluginApiCallbacks(
        this.pluginApiIdentifiers,
        this
      );
      this._boundaryActionHandler("onSelectNone");
      this.clearSelection();
      return;
    }

    if (computedContentItem.__sk_row_type === "noopRow") {
      applyOnSelectPluginApiCallbacks(
        this.pluginApiIdentifiers,
        computedContentItem.value,
        this
      );

      this._boundaryActionHandler("onSelect", computedContentItem.value);
      return;
    }

    if (computedContentItem.__sk_row_type === "createRow") {
      if (
        !this.computedValues.includes(computedContentItem.value) &&
        this.validateCreate(computedContentItem.value)
      ) {
        this.willCreate(computedContentItem);

        computedContentItem.__sk_row_type = null;
        this.computedContent.pushObject(computedContentItem);

        run.schedule("afterRender", () => {
          this.didCreate(computedContentItem);
          this._boundaryActionHandler("onCreate");
        });

        this.select(computedContentItem);
        return;
      } else {
        this._boundaryActionHandler("onCreateFailure");
        return;
      }
    }

    if (this.validateSelect(computedContentItem)) {
      this.willSelect(computedContentItem);
      this.clearFilter();
      this.setProperties({ highlighted: null });
      this.computedValues.pushObject(computedContentItem.value);

      run.next(() => this.mutateAttributes());

      run.schedule("afterRender", () => {
        this.didSelect(computedContentItem);

        applyOnSelectPluginApiCallbacks(
          this.pluginApiIdentifiers,
          computedContentItem.value,
          this
        );

        this.autoHighlight();

        this._boundaryActionHandler("onSelect", computedContentItem.value);
      });
    } else {
      this._boundaryActionHandler("onSelectFailure");
    }
  },

  deselect(rowComputedContentItems) {
    this.willDeselect(rowComputedContentItems);

    rowComputedContentItems = makeArray(rowComputedContentItems);
    const generatedComputedContents = this._filterRemovableComputedContents(
      makeArray(rowComputedContentItems)
    );
    this.setProperties({ highlighted: null, highlightedSelection: [] });
    this.computedValues.removeObjects(
      rowComputedContentItems.map(r => r.value)
    );
    this.computedContent.removeObjects([
      ...rowComputedContentItems,
      ...generatedComputedContents
    ]);

    run.next(() => {
      this.mutateAttributes();

      run.schedule("afterRender", () => {
        this.didDeselect(rowComputedContentItems);
        this.autoHighlight();

        if (!this.isDestroying && !this.isDestroyed) {
          this._positionWrapper();
        }
      });
    });
  },

  close(event) {
    this.clearHighlightSelection();

    this._super(event);
  },

  unfocus(event) {
    this.clearHighlightSelection();

    this._super(event);
  }
});
