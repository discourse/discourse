import SelectKitComponent from "select-kit/components/select-kit";
import computed from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";
const { get, isNone, isEmpty, makeArray, run } = Ember;
import { applyOnSelectPluginApiCallbacks } from "select-kit/mixins/plugin-api";

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
    this._super();

    this.set("computedValues", []);

    if (isNone(this.get("values"))) {
      this.set("values", []);
    }

    this.set(
      "headerComponentOptions",
      Ember.Object.create({
        selectedNameComponent: this.get("selectedNameComponent")
      })
    );
  },

  @on("didRender")
  _setChoicesMaxWidth() {
    const width = this.$body().outerWidth(false);
    this.$(".choices").css({ maxWidth: width, width });
  },

  @on("didReceiveAttrs")
  _compute() {
    run.scheduleOnce("afterRender", () => {
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
      if (this.get("isDestroyed") || this.get("isDestroying")) return;

      this.mutateContent(this.get("computedContent"));
      this.mutateValues(this.get("computedValues"));
    });
  },
  mutateValues(computedValues) {
    this.set("values", computedValues);
  },
  mutateContent() {},

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
      computedContent = this.filterComputedContent(
        computedContent,
        computedValues,
        this._normalize(filter)
      );
    }

    if (this.get("limitMatches")) {
      return computedContent.slice(0, this.get("limitMatches"));
    }

    return computedContent;
  },

  computeHeaderContent() {
    let content = {
      title: this.get("title"),
      selection: this.get("selection")
    };

    if (this.get("noneLabel")) {
      if (!this.get("hasSelection")) {
        content.title = content.name = content.label = I18n.t(
          this.get("noneLabel")
        );
      }
    } else {
      if (!this.get("hasReachedMinimum")) {
        const key =
          this.get("minimumLabel") || "select_kit.min_content_not_reached";
        content.title = content.name = content.label = I18n.t(key, {
          count: this.get("minimum")
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
    return this._super() && !this.get("hasReachedMaximum");
  },

  @computed("computedValues.[]", "computedContent.[]")
  selection(computedValues, computedContent) {
    const selected = [];

    computedValues.forEach(v => {
      const value = computedContent.findBy("value", v);
      if (value) selected.push(value);
    });

    return selected;
  },

  @computed("selection.[]")
  hasSelection(selection) {
    return !isEmpty(selection);
  },

  didPressTab(event) {
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

  autoHighlight() {
    run.schedule("afterRender", () => {
      if (!this.get("isExpanded")) return;
      if (!this.get("renderedBodyOnce")) return;
      if (this.get("highlighted")) return;

      if (isEmpty(this.get("collectionComputedContent"))) {
        if (this.get("createRowComputedContent")) {
          this.highlight(this.get("createRowComputedContent"));
        } else if (
          this.get("noneRowComputedContent") &&
          this.get("hasSelection")
        ) {
          this.highlight(this.get("noneRowComputedContent"));
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
      this.clearSelection();
      return;
    }

    if (computedContentItem.__sk_row_type === "createRow") {
      if (
        !this.get("computedValues").includes(computedContentItem.value) &&
        this.validateCreate(computedContentItem.value)
      ) {
        this.willCreate(computedContentItem);

        computedContentItem.__sk_row_type = null;
        this.get("computedContent").pushObject(computedContentItem);

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
      this.get("computedValues").pushObject(computedContentItem.value);

      run.next(() => this.mutateAttributes());

      run.schedule("afterRender", () => {
        this.didSelect(computedContentItem);

        applyOnSelectPluginApiCallbacks(
          this.get("pluginApiIdentifiers"),
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
    this.set("highlighted", null);
    this.set("highlightedSelection", []);
    this.get("computedValues").removeObjects(
      rowComputedContentItems.map(r => r.value)
    );
    this.get("computedContent").removeObjects(generatedComputedContents);
    run.next(() => this.mutateAttributes());
    run.schedule("afterRender", () => {
      this.didDeselect(rowComputedContentItems);
      this.autoHighlight();
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
