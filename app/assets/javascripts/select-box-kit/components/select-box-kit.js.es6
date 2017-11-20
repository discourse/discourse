const { get, isNone, isEmpty, isPresent } = Ember;
import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import UtilsMixin from "select-box-kit/mixins/utils";
import DomHelpersMixin from "select-box-kit/mixins/dom-helpers";
import KeyboardMixin from "select-box-kit/mixins/keyboard";
import PluginApiMixin from "select-box-kit/mixins/plugin-api";
import { applyContentPluginApiCallbacks } from "select-box-kit/mixins/plugin-api";

export default Ember.Component.extend(UtilsMixin, PluginApiMixin, DomHelpersMixin, KeyboardMixin, {
  pluginApiIdentifiers: ["select-box-kit"],
  layoutName: "select-box-kit/templates/components/select-box-kit",
  classNames: "select-box-kit",
  classNameBindings: [
    "isFocused",
    "isExpanded",
    "isDisabled",
    "isHidden",
    "isAbove",
    "isBelow",
    "isLeftAligned",
    "isRightAligned"
  ],
  isDisabled: false,
  isExpanded: false,
  isFocused: false,
  isHidden: false,
  renderedBodyOnce: false,
  renderedFilterOnce: false,
  tabindex: 0,
  scrollableParentSelector: ".modal-body",
  value: null,
  none: null,
  highlightedValue: null,
  noContentLabel: "select_box.no_content",
  valueAttribute: "id",
  nameProperty: "name",
  autoFilterable: false,
  filterable: false,
  filter: "",
  filterPlaceholder: "select_box.filter_placeholder",
  filterIcon: "search",
  rowComponent: "select-box-kit/select-box-kit-row",
  rowComponentOptions: null,
  noneRowComponent: "select-box-kit/select-box-kit-none-row",
  createRowComponent: "select-box-kit/select-box-kit-create-row",
  filterComponent: "select-box-kit/select-box-kit-filter",
  headerComponent: "select-box-kit/select-box-kit-header",
  headerComponentOptions: null,
  headerComputedContent: null,
  collectionComponent: "select-box-kit/select-box-kit-collection",
  collectionHeight: 200,
  verticalOffset: 0,
  horizontalOffset: 0,
  fullWidthOnMobile: false,
  castInteger: false,
  allowAny: false,
  allowInitialValueMutation: false,
  autoSelectFirst: true,
  content: null,
  computedValue: null,
  computedContent: null,
  _initialValues: null,

  init() {
    this._super();

    this.noneValue = "__none__";
    this._previousScrollParentOverflow = "auto";
    this._previousCSSContext = {};
    this.set("headerComponentOptions", Ember.Object.create());
    this.set("rowComponentOptions", Ember.Object.create());
    this.set("computedContent", []);

    if ($(window).outerWidth(false) <= 420) {
      this.setProperties({ filterable: false, autoFilterable: false });
    }
  },

  @on("didReceiveAttrs")
  _compute() {
    Ember.run.scheduleOnce("afterRender", () => {
      this.willComputeAttributes();
      let content = this._beforeWillComputeContent(this.get("content"));
      content = this.willComputeContent(content);
      let value = this._beforeWillComputeValue(value);
      content = this.computeContent(content);
      content = this._beforeDidComputeContent(content);
      value = this.willComputeValue(this.get("value"));
      value = this.computeValue(value);
      value = this._beforeDidComputeValue(value);
      this.didComputeContent(content);
      this.didComputeValue(value);
      this.set("headerComputedContent", this.computeHeaderContent());
      this.didComputeAttributes();
    });
  },

  willComputeAttributes() {},
  didComputeAttributes() {},

  _beforeWillComputeContent(content) { return Ember.makeArray(content); },
  willComputeContent(content) { return content; },
  computeContent(content) { return content; },
  _beforeDidComputeContent(content) {
    content = applyContentPluginApiCallbacks(this.get("pluginApiIdentifiers"), content);
    this.setProperties({
      computedContent: content.map(c => this.computeContentItem(c)),
      _initialValues: this.get("_initialValues") || content.map(c => this._valueForContent(c) )
    });
    return content;
  },
  didComputeContent(content) { return content; },

  _beforeWillComputeValue(value) {
    value = this._castInteger(value === "" ? null : value);

    if (this.get("allowInitialValueMutation") === true) {
      const none = isNone(this.get("none"));
      const emptyValue = isEmpty(value);
      if (none && emptyValue) {
        if (!isEmpty(this.get("content"))) {
          value = this._valueForContent(this.get("content.firstObject"));
          Ember.run.next(() => this.mutateValue(value));
        }
      }
    }
    return value;
  },
  willComputeValue(value) { return value; },
  computeValue(value) { return value; },
  _beforeDidComputeValue(value) {
    if (!isEmpty(this.get("content")) && isNone(value) && isNone(this.get("none"))) {
      value = this._valueForContent(get(this.get("content"), "firstObject"));
    }

    this.setProperties({ computedValue: value });
    return value;
  },
  didComputeValue(value) { return value; },

  mutateAttributes() {
    Ember.run.next(() => {
      this.mutateContent(this.get("computedContent"));
      this.mutateValue(this.get("computedValue"));
      this.set("headerComputedContent", this.computeHeaderContent());
    });
  },
  mutateContent() {},
  mutateValue(computedValue) { this.set("value", computedValue); },

  filterComputedContent(computedContent, computedValue, filter) {
    if (isEmpty(filter)) { return computedContent; }
    const lowerFilter = filter.toLowerCase();
    return computedContent.filter(c => {
      return get(c, "name").toLowerCase().indexOf(lowerFilter) > -1;
    });
  },

  computeHeaderContent() {
    return this.baseHeaderComputedContent();
  },

  baseHeaderComputedContent() {
    return {
      name: this.get("selectedComputedContent.name") || this.get("noneRowComputedContent.name")
    };
  },

  computeContentItem(contentItem, name) {
    return this.baseComputedContentItem(contentItem, name);
  },

  baseComputedContentItem(contentItem, name) {
    let originalContent;

    if (typeof contentItem === "string" || typeof contentItem === "number") {
      originalContent = {};
      originalContent[this.get("valueAttribute")] = contentItem;
      originalContent[this.get("nameProperty")] = name || contentItem;
    } else {
      originalContent = contentItem;
    }

    return {
      value: this._castInteger(this._valueForContent(contentItem)),
      name: name || this._nameForContent(contentItem),
      locked: false,
      originalContent
    };
  },

  @computed("computedContent.[]", "computedValue.[]", "filter")
  filteredComputedContent(computedContent, computedValue, filter) {
    return this.filterComputedContent(computedContent, computedValue, filter);
  },

  @computed("filter", "filterable", "autoFilterable", "renderedFilterOnce")
  shouldDisplayFilter(filter, filterable, autoFilterable, renderedFilterOnce) {
    if ((renderedFilterOnce === true || filterable === true) && filter.length > 0) { return true; }
    if (filter.length > 0 && autoFilterable === true) { return true; }
    return false;
  },

  @computed("filter")
  shouldDisplayCreateRow(filter) {
    if (this.get("allowAny") === true && filter.length > 0) { return true; }
    return false;
  },

  @computed("filter", "shouldDisplayCreateRow")
  createRowComputedContent(filter, shouldDisplayCreateRow) {
    if (shouldDisplayCreateRow === true && !this.get("computedValue") === filter) {
      let content = this.createContentFromInput(filter);
      return this.computeContentItem(content);
    }
  },

  @computed
  templateForRow() { return () => null; },

  @computed
  templateForNoneRow() { return () => null; },

  @computed
  templateForCreateRow() { return () => null; },

  @computed("none")
  noneRowComputedContent(none) {
    if (isNone(none)) { return null; }

    switch (typeof none) {
    case "string":
      return this.computeContentItem(this.noneValue, I18n.t(none));
    default:
      return this.computeContentItem(none);
    }
  },

  @computed("computedValue", "computedContent.[]")
  selectedComputedContent(computedValue, computedContent) {
    if (isNone(computedValue) || isNone(computedContent)) { return []; }
    return computedContent.findBy("value", computedValue);
  },

  autoHighlight() {
    Ember.run.schedule("afterRender", () => {
      if (!isNone(this.get("highlightedValue"))) { return; }

      const filteredComputedContent = this.get("filteredComputedContent");
      const displayCreateRow = this.get("shouldDisplayCreateRow");
      const none = this.get("noneRowComputedContent");

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

  createContentFromInput(input) { return input; },

  validateComputedContent() { return true; },

  willSelect() {
    this.clearFilter();
    this.set("highlightedValue", null);
  },
  didSelect() {
    this.collapse();
    this.focus();
  },

  willDeselect() { this.set("highlightedValue", null); },
  didDeselect() { this.focus(); },

  clearFilter() {
    this.$filterInput().val("");
    this.setProperties({ filter: "" });
  },

  actions: {
    onToggle() {
      this.get("isExpanded") === true ? this.collapse() : this.expand();
    },

    onClear() {
      this.set("computedValue", null);
      this.mutateAttributes();
    },

    onHighlight(rowComputedContent) {
      this.set("highlightedValue", rowComputedContent.value);
    },

    onCreate(input) {
      let content = this.createContentFromInput(input);
      if (!Ember.isNone(content)) return;

      const computedContent = this.computeContentItem(content);
      if (this.validateComputedContent(computedContent) &&
          this.get("computedValue") !== computedContent.value) {
        this.get("computedContent").pushObject(computedContent);
        this.set("computedValue", computedContent.value);
        this.clearFilter();
        this.autoHighlight();
        this.send("onSelect", computedContent);
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
    },

    onFilter(filter) {
      this.expand();
      this.setProperties({
        highlightedValue: null,
        renderedFilterOnce: true,
        filter
      });
      this.autoHighlight();
    }
  }
});
