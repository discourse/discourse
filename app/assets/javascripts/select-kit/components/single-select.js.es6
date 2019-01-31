import SelectKitComponent from "select-kit/components/select-kit";
import {
  default as computed,
  on
} from "ember-addons/ember-computed-decorators";
const { get, isNone, isEmpty, isPresent, run, makeArray } = Ember;

import {
  applyOnSelectPluginApiCallbacks,
  applyOnSelectNonePluginApiCallbacks
} from "select-kit/mixins/plugin-api";

export default SelectKitComponent.extend({
  pluginApiIdentifiers: ["single-select"],
  layoutName: "select-kit/templates/components/single-select",
  classNames: "single-select",
  computedValue: null,
  value: null,
  allowInitialValueMutation: false,

  @on("didReceiveAttrs")
  _compute() {
    run.scheduleOnce("afterRender", () => {
      this.willComputeAttributes();
      let content = this.get("content") || [];
      let asyncContent = this.get("asyncContent") || [];
      content = this.willComputeContent(content);
      asyncContent = this.willComputeAsyncContent(asyncContent);
      let value = this._beforeWillComputeValue(this.get("value"));
      content = this.computeContent(content);
      asyncContent = this.computeAsyncContent(asyncContent);
      content = this._beforeDidComputeContent(content);
      asyncContent = this._beforeDidComputeAsyncContent(asyncContent);
      value = this.willComputeValue(value);
      value = this.computeValue(value);
      value = this._beforeDidComputeValue(value);
      this.didComputeContent(content);
      this.didComputeAsyncContent(asyncContent);
      this.didComputeValue(value);
      this.didComputeAttributes();

      if (this.get("allowInitialValueMutation")) this.mutateAttributes();
    });
  },

  mutateAttributes() {
    run.next(() => {
      if (this.get("isDestroyed") || this.get("isDestroying")) return;

      this.mutateContent(this.get("computedContent"));
      this.mutateValue(this.get("computedValue"));
    });
  },
  mutateContent() {},
  mutateValue(computedValue) {
    this.set("value", computedValue);
  },

  forceValue(value) {
    this.mutateValue(value);
    this._compute();
  },

  _beforeWillComputeValue(value) {
    if (
      !isEmpty(this.get("content")) &&
      isEmpty(value) &&
      isNone(this.get("none")) &&
      this.get("allowAutoSelectFirst")
    ) {
      value = this.valueForContentItem(get(this.get("content"), "firstObject"));
    }

    switch (typeof value) {
      case "string":
      case "number":
        return this._cast(value === "" ? null : value);
      default:
        return value;
    }
  },
  willComputeValue(value) {
    return value;
  },
  computeValue(value) {
    return value;
  },
  _beforeDidComputeValue(value) {
    this.setProperties({ computedValue: value });
    return value;
  },
  didComputeValue(value) {
    return value;
  },

  filterComputedContent(computedContent, computedValue, filter) {
    return computedContent.filter(c => {
      return this._normalize(get(c, "name")).indexOf(filter) > -1;
    });
  },

  computeHeaderContent() {
    let content = {
      title: this.get("title"),
      icons: makeArray(this.getWithDefault("headerIcon", [])),
      value: this.get("selection.value"),
      name:
        this.get("selection.name") || this.get("noneRowComputedContent.name")
    };

    if (this.get("noneLabel") && !this.get("hasSelection")) {
      content.title = content.name = I18n.t(this.get("noneLabel"));
    }

    return content;
  },

  @computed("computedAsyncContent.[]", "computedValue")
  filteredAsyncComputedContent(computedAsyncContent, computedValue) {
    computedAsyncContent = computedAsyncContent.filter(c => {
      return computedValue !== get(c, "value");
    });

    if (this.get("limitMatches")) {
      return computedAsyncContent.slice(0, this.get("limitMatches"));
    }

    return computedAsyncContent;
  },

  @computed("computedContent.[]", "computedValue", "filter", "shouldFilter")
  filteredComputedContent(
    computedContent,
    computedValue,
    filter,
    shouldFilter
  ) {
    if (shouldFilter) {
      computedContent = this.filterComputedContent(
        computedContent,
        computedValue,
        this._normalize(filter)
      );
    }

    if (this.get("limitMatches")) {
      return computedContent.slice(0, this.get("limitMatches"));
    }

    return computedContent;
  },

  @computed("computedValue", "computedContent.[]")
  selection(computedValue, computedContent) {
    return computedContent.findBy("value", computedValue);
  },

  @computed("selection")
  hasSelection(selection) {
    return (
      selection !== this.get("noneRowComputedContent") && !isNone(selection)
    );
  },

  @computed(
    "computedValue",
    "filter",
    "collectionComputedContent.[]",
    "hasReachedMaximum",
    "hasReachedMinimum"
  )
  shouldDisplayCreateRow(computedValue, filter) {
    return this._super() && computedValue !== filter;
  },

  autoHighlight() {
    run.schedule("afterRender", () => {
      if (this.get("shouldDisplayCreateRow")) {
        this.highlight(this.get("createRowComputedContent"));
        return;
      }

      if (
        !isEmpty(this.get("filter")) &&
        !isEmpty(this.get("collectionComputedContent"))
      ) {
        this.highlight(this.get("collectionComputedContent.firstObject"));
        return;
      }

      if (
        !this.get("isAsync") &&
        this.get("hasSelection") &&
        isEmpty(this.get("filter"))
      ) {
        this.highlight(get(makeArray(this.get("selection")), "firstObject"));
        return;
      }

      if (
        !this.get("isAsync") &&
        !this.get("hasSelection") &&
        isEmpty(this.get("filter")) &&
        !isEmpty(this.get("collectionComputedContent"))
      ) {
        this.highlight(this.get("collectionComputedContent.firstObject"));
        return;
      }

      if (isPresent(this.get("noneRowComputedContent"))) {
        this.highlight(this.get("noneRowComputedContent"));
        return;
      }
    });
  },

  select(computedContentItem) {
    if (computedContentItem.__sk_row_type === "noopRow") {
      applyOnSelectPluginApiCallbacks(
        this.get("pluginApiIdentifiers"),
        computedContentItem.value,
        this
      );

      this._boundaryActionHandler("onSelect", computedContentItem.value);
      return;
    }

    if (this.get("hasSelection")) {
      this.deselect(this.get("selection.value"));
    }

    if (
      !computedContentItem ||
      computedContentItem.__sk_row_type === "noneRow"
    ) {
      applyOnSelectNonePluginApiCallbacks(
        this.get("pluginApiIdentifiers"),
        this
      );
      this._boundaryActionHandler("onSelectNone");
      this.clearSelection();
      return;
    }

    if (computedContentItem.__sk_row_type === "createRow") {
      if (
        this.get("computedValue") !== computedContentItem.value &&
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
      this.setProperties({
        highlighted: null,
        computedValue: computedContentItem.value
      });

      run.next(() => this.mutateAttributes());

      run.schedule("afterRender", () => {
        this.didSelect(computedContentItem);

        applyOnSelectPluginApiCallbacks(
          this.get("pluginApiIdentifiers"),
          computedContentItem.value,
          this
        );

        this._boundaryActionHandler("onSelect", computedContentItem.value);

        this.autoHighlight();
      });
    } else {
      this._boundaryActionHandler("onSelectFailure");
    }
  },

  deselect(computedContentItem) {
    makeArray(computedContentItem).forEach(item => {
      this.willDeselect(item);

      this.clearFilter();

      this.setProperties({
        computedValue: null,
        highlighted: null,
        highlightedSelection: []
      });

      run.next(() => this.mutateAttributes());
      run.schedule("afterRender", () => {
        this.didDeselect(item);
        this._boundaryActionHandler("onDeselect", item);
        this.autoHighlight();
      });
    });
  }
});
