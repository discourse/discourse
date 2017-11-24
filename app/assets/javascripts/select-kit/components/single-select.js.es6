import SelectKitComponent from "select-kit/components/select-kit";
import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
const { get, isNone, isEmpty, isPresent, run } = Ember;
import {
  applyOnSelectPluginApiCallbacks
} from "select-kit/mixins/plugin-api";

export default SelectKitComponent.extend({
  pluginApiIdentifiers: ["single-select"],
  classNames: "single-select",
  computedValue: null,
  value: null,
  allowInitialValueMutation: false,

  @on("didReceiveAttrs")
  _compute() {
    Ember.run.scheduleOnce("afterRender", () => {
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
      this.set("headerComputedContent", this.computeHeaderContent());
      this.didComputeAttributes();

      if (this.get("allowInitialValueMutation")) this.mutateAttributes();
    });
  },

  mutateAttributes() {
    run.next(() => {
      this.mutateContent(this.get("computedContent"));
      this.mutateValue(this.get("computedValue"));
      applyOnSelectPluginApiCallbacks(this.get("pluginApiIdentifiers"), this.get("computedValue"), this);
      this.set("headerComputedContent", this.computeHeaderContent());
    });
  },
  mutateContent() {},
  mutateValue(computedValue) {
    this.set("value", computedValue);
  },

  _beforeWillComputeValue(value) {
    if (!isEmpty(this.get("content")) && isEmpty(value) && isNone(this.get("none"))) {
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
      icons: Ember.makeArray(this.getWithDefault("headerIcon", [])),
      name: this.get("selectedComputedContent.name") || this.get("noneRowComputedContent.name")
    };
  },

  @computed("computedContent.[]", "computedValue", "filter", "shouldFilter")
  filteredComputedContent(computedContent, computedValue, filter, shouldFilter) {
    if (shouldFilter === true) {
      computedContent = this.filterComputedContent(computedContent, computedValue, filter);
    }

    return computedContent.slice(0, this.get("limitMatches"));
  },

  @computed("computedValue", "computedContent.[]")
  selectedComputedContent(computedValue, computedContent) {
    if (isNone(computedValue) || isNone(computedContent)) { return null; }
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
    Ember.run.schedule("afterRender", () => {
      if (!isNone(this.get("highlightedValue"))) { return; }

      const filteredComputedContent = this.get("filteredComputedContent");
      const displayCreateRow = this.get("shouldDisplayCreateRow");
      const none = this.get("noneRowComputedContent");

      if (this.get("hasSelection") && isEmpty(this.get("filter"))) {
        this.send("onHighlight", this.get("selectedComputedContent"));
        return;
      }

      if (isNone(this.get("highlightedValue")) && !isEmpty(filteredComputedContent)) {
        this.send("onHighlight", get(filteredComputedContent, "firstObject"));
        return;
      }

      if (displayCreateRow === true && isEmpty(filteredComputedContent)) {
        this.send("onHighlight", this.get("createRowComputedContent"));
      }
      else if (!isEmpty(filteredComputedContent)) {
        this.send("onHighlight", get(filteredComputedContent, "firstObject"));
      }
      else if (isEmpty(filteredComputedContent) && isPresent(none) && displayCreateRow === false) {
        this.send("onHighlight", none);
      }
    });
  },

  validateComputedContentItem(computedContentItem) {
    return this.get("computedValue") !== computedContentItem.value;
  },

  actions: {
    onClear() {
      this.send("onDeselect", this.get("selectedComputedContent"));
    },

    onCreate(computedContentItem) {
      if (this.validateComputedContentItem(computedContentItem)) {
        this.get("computedContent").pushObject(computedContentItem);
        this.send("onSelect", computedContentItem);
      }
    },

    onSelect(rowComputedContentItem) {
      this.willSelect(rowComputedContentItem);
      this.set("computedValue", rowComputedContentItem.value);
      this.mutateAttributes();
      Ember.run.schedule("afterRender", () => this.didSelect(rowComputedContentItem));
    },

    onDeselect(rowComputedContentItem) {
      this.willDeselect(rowComputedContentItem);
      this.set("computedValue", null);
      this.mutateAttributes();
      Ember.run.schedule("afterRender", () => this.didDeselect(rowComputedContentItem));
    }
  }
});
