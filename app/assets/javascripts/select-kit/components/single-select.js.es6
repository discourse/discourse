import SelectKitComponent from "select-kit/components/select-kit";
import { default as computed, on } from 'ember-addons/ember-computed-decorators';
const { get, isNone, isEmpty, isPresent, run } = Ember;

export default SelectKitComponent.extend({
  pluginApiIdentifiers: ["single-select"],
  classNames: "single-select",
  computedValue: null,
  value: null,
  allowInitialValueMutation: false,

  @on("didReceiveAttrs")
  _compute() {
    run.scheduleOnce("afterRender", () => {
      this.willComputeAttributes();
      let content = this.willComputeContent(this.get("content") || []);
      let value = this._beforeWillComputeValue(this.get("value"));
      content = this.computeContent(content);
      content = this._beforeDidComputeContent(content);
      value = this.willComputeValue(value);
      value = this.computeValue(value);
      value = this._beforeDidComputeValue(value);
      this.didComputeContent(content);
      this.didComputeValue(value);
      this.didComputeAttributes();

      if (this.get("allowInitialValueMutation")) this.mutateAttributes();

      this._setHeaderComputedContent();
    });
  },

  mutateAttributes() {
    if (this.get("isDestroyed") || this.get("isDestroying")) return;

    run.next(() => {
      this.mutateContent(this.get("computedContent"));
      this.mutateValue(this.get("computedValue"));
      this._setHeaderComputedContent();
    });
  },
  mutateContent() {},
  mutateValue(computedValue) {
    this.set("value", computedValue);
  },

  _beforeWillComputeValue(value) {
    if (!isEmpty(this.get("content")) &&
      isEmpty(value) &&
      isNone(this.get("none")) &&
      this.get("allowAutoSelectFirst")) {
        value = this.valueForContentItem(get(this.get("content"), "firstObject"));
    }

    switch (typeof value) {
    case "string":
    case "number":
      return this._castInteger(value === "" ? null : value);
    default:
      return value;
    }
  },
  willComputeValue(value) { return value; },
  computeValue(value) { return value; },
  _beforeDidComputeValue(value) {
    this.setProperties({ computedValue: value });
    return value;
  },
  didComputeValue(value) { return value; },

  filterComputedContent(computedContent, computedValue, filter) {
    const lowerFilter = filter.toLowerCase();
    return computedContent.filter(c => {
      return get(c, "name").toLowerCase().indexOf(lowerFilter) > -1;
    });
  },

  baseHeaderComputedContent() {
    return {
      title: this.get("title"),
      icons: Ember.makeArray(this.getWithDefault("headerIcon", [])),
      value: this.get("selectedComputedContent.value"),
      name: this.get("selectedComputedContent.name") || this.get("noneRowComputedContent.name")
    };
  },

  @computed("computedContent.[]", "computedValue", "filter", "shouldFilter")
  filteredComputedContent(computedContent, computedValue, filter, shouldFilter) {
    if (shouldFilter) {
      computedContent = this.filterComputedContent(computedContent, computedValue, filter);
    }

    if (this.get("limitMatches")) {
      return computedContent.slice(0, this.get("limitMatches"));
    }

    return computedContent;
  },

  @computed("computedValue", "computedContent.[]")
  selectedComputedContent(computedValue, computedContent) {
    return computedContent.findBy("value", computedValue);
  },

  @computed("selectedComputedContent")
  hasSelection(selectedComputedContent) {
    return selectedComputedContent !== this.get("noneRowComputedContent") &&
      !Ember.isNone(selectedComputedContent);
  },

  @computed("filter", "computedValue")
  shouldDisplayCreateRow(filter, computedValue) {
    return this._super() && computedValue !== filter;
  },

  autoHighlight() {
    run.schedule("afterRender", () => {
      if (!isNone(this.get("highlightedValue"))) return;

      const filteredComputedContent = this.get("filteredComputedContent");
      const displayCreateRow = this.get("shouldDisplayCreateRow");
      const none = this.get("noneRowComputedContent");

      if (this.get("hasSelection") && isEmpty(this.get("filter"))) {
        this.send("highlight", this.get("selectedComputedContent"));
        return;
      }

      if (isNone(this.get("highlightedValue")) && !isEmpty(filteredComputedContent)) {
        this.send("highlight", get(filteredComputedContent, "firstObject"));
        return;
      }

      if (displayCreateRow && isEmpty(filteredComputedContent)) {
        this.send("highlight", this.get("createRowComputedContent"));
      }
      else if (!isEmpty(filteredComputedContent)) {
        this.send("highlight", get(filteredComputedContent, "firstObject"));
      }
      else if (isEmpty(filteredComputedContent) && isPresent(none) && !displayCreateRow) {
        this.send("highlight", none);
      }
    });
  },

  validateComputedContentItem(computedContentItem) {
    return this.get("computedValue") !== computedContentItem.value;
  },

  actions: {
    clearSelection() {
      this.send("deselect", this.get("selectedComputedContent"));
      this._boundaryActionHandler("onClearSelection");
    },

    create(computedContentItem) {
      if (this.validateComputedContentItem(computedContentItem)) {
        this.get("computedContent").pushObject(computedContentItem);
        this._boundaryActionHandler("onCreate");
        this.send("select", computedContentItem);
      } else {
        this._boundaryActionHandler("onCreateFailure");
      }
    },

    select(rowComputedContentItem) {
      this.willSelect(rowComputedContentItem);
      this.set("computedValue", rowComputedContentItem.value);
      this.mutateAttributes();
      run.schedule("afterRender", () => this.didSelect(rowComputedContentItem));
    },

    deselect(rowComputedContentItem) {
      this.willDeselect(rowComputedContentItem);
      this.set("computedValue", null);
      this.mutateAttributes();
      run.schedule("afterRender", () => this.didDeselect(rowComputedContentItem));
    }
  }
});
