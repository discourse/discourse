const { get, isNone, isEmpty, isPresent } = Ember;
import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import UtilsMixin from "select-box-kit/mixins/utils";
import DomHelpersMixin from "select-box-kit/mixins/dom-helpers";
import KeyboardMixin from "select-box-kit/mixins/keyboard";

export default Ember.Component.extend(UtilsMixin, DomHelpersMixin, KeyboardMixin, {
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
  noneRowComponent: "select-box-kit/select-box-kit-none-row",
  createRowComponent: "select-box-kit/select-box-kit-create-row",
  filterComponent: "select-box-kit/select-box-kit-filter",
  headerComponent: "select-box-kit/select-box-kit-header",
  collectionComponent: "select-box-kit/select-box-kit-collection",
  collectionHeight: 200,
  verticalOffset: 0,
  horizontalOffset: 0,
  fullWidthOnMobile: false,
  castInteger: false,
  allowAny: false,
  allowValueMutation: true,
  autoSelectFirst: true,
  content: null,
  _initialValues: null,

  init() {
    this._super();

    this.noneValue = "__none__";

    if ($(window).outerWidth(false) <= 420) {
      this.setProperties({ filterable: false, autoFilterable: false });
    }

    this._previousScrollParentOverflow = "auto";
    this._previousCSSContext = {};

    if (isNone(this.get("content"))) { this.set("content", []); }

    this.setInitialValues();
  },

  setInitialValues() {
    this.set("_initialValues", this.getWithDefault("content", []).map((c) => {
      return this.valueForContent(c);
    }));
  },

  createFunction(input) { return () => input; },

  filterFunction(computedContent, filter) {
    return () => {
      const lowerFilter = filter.toLowerCase();
      return _.filter(computedContent, c => {
        return get(c, "name").toString().toLowerCase().indexOf(lowerFilter) > -1;
      });
    };
  },

  nameForContent(content) {
    if (isNone(content)) {
      return null;
    }

    if (typeof content === "object") {
      return get(content, this.get("nameProperty"));
    }

    return content;
  },

  valueForContent(content) {
    switch (typeof content) {
    case "string":
    case "number":
      return this._castInteger(content);
    default:
      return this._castInteger(get(content, this.get("valueAttribute")));
    }
  },

  contentForValue(value) {
    return this.get("content").find(c => {
      if (this.valueForContent(c) === value) { return true; }
    });
  },

  computedContentForValue(value) {
    const searchedValue = value.toString();
    return this.get("computedContent").find(c => {
      if (c.value.toString() === searchedValue) { return true; }
    });
  },

  formatRowContent(content) {
    let originalContent;

    if (typeof content === "string" || typeof content === "number") {
      originalContent = {};
      originalContent[this.get("valueAttribute")] = content;
      originalContent[this.get("nameProperty")] = content;
    } else {
      originalContent = content;
    }

    return {
      value: this.valueForContent(content),
      name: this.nameForContent(content),
      locked: false,
      originalContent
    };
  },

  formatContents(contents) {
    return contents.map(content => this.formatRowContent(content));
  },

  @computed("filter", "filterable", "autoFilterable", "renderedFilterOnce")
  shouldDisplayFilter(filter, filterable, autoFilterable, renderedFilterOnce) {
    if (renderedFilterOnce === true || filterable === true) { return true; }
    if (filter.length > 0 && autoFilterable === true) { return true; }
    return false;
  },

  @computed("filter")
  shouldDisplayCreateRow(filter) {
    if (this.get("allowAny") === true && filter.length > 0) { return true; }
    return false;
  },

  @computed("filter", "shouldDisplayCreateRow")
  createRowContent(filter, shouldDisplayCreateRow) {
    if (shouldDisplayCreateRow === true) {
      return Ember.Object.create({ value: filter, name: filter });
    }
  },

  @computed("content.[]", "value.[]")
  computedContent(content) {
    this._mutateValue();
    return this.formatContents(content || []);
  },

  @computed("value", "none", "computedContent.firstObject.value")
  computedValue(value, none, firstContentValue) {
    if (isNone(value) && isNone(none) && this.get("autoSelectFirst") === true) {
      return this._castInteger(firstContentValue);
    }

    return this._castInteger(value);
  },

  @computed
  templateForRow() { return () => null; },

  @computed
  templateForNoneRow() { return () => null; },

  @computed
  templateForCreateRow() { return () => null; },

  @computed("none")
  computedNone(none) {
    if (isNone(none)) { return null; }

    switch (typeof none) {
    case "string":
      return Ember.Object.create({ name: I18n.t(none), value: this.noneValue });
    default:
      return this.formatRowContent(none);
    }
  },

  @computed("computedValue", "computedContent.[]")
  selectedContent(computedValue, computedContent) {
    if (isNone(computedValue)) { return []; }
    return [ computedContent.findBy("value", this._castInteger(computedValue)) ];
  },

  @on("didInsertElement")
  _setupResizeListener() {
    $(window).on("resize.select-box-kit", () => this.collapse() );
  },

  @on("willRender")
  autoHighlight() {
    if (!isNone(this.get("highlightedValue"))) { return; }

    const filteredContent = this.get("filteredContent");
    const display = this.get("shouldDisplayCreateRow");
    const none = this.get("computedNone");

    if (isNone(this.get("highlightedValue")) && !isEmpty(filteredContent)) {
      this.send("onHighlight", get(filteredContent, "firstObject.value"));
      return;
    }

    if (display === true && isEmpty(filteredContent)) {
      this.send("onHighlight", this.get("filter"));
    }
    else if (!isEmpty(filteredContent)) {
      this.send("onHighlight", get(filteredContent, "firstObject.value"));
    }
    else if (isEmpty(filteredContent) && isPresent(none) && display === false) {
      this.send("onHighlight", get(none, "value"));
    }
  },

  @computed("computedContent.[]", "filter")
  filteredContent(computedContent, filter) {
    return this.filterFunction(computedContent, filter)(this);
  },

  @computed("scrollableParentSelector")
  scrollableParent(scrollableParentSelector) {
    return this.$().parents(scrollableParentSelector).first();
  },

  baseOnCreateContent(input) {
    this.set("highlightedValue", null);
    this.clearFilter();
    return this.createFunction(input)(this);
  },

  baseOnHighlight(value) { return this.originalValueForValue(value); },

  baseOnSelect(value) {
    if (value === "") { value = null; }
    this.clearFilter();
    this.set("highlightedValue", null);
    this.collapse();
    return this.originalValueForValue(value);
  },

  baseOnDeselect() {},

  baseOnClearSelection() {
    this.clearFilter();
    this.focus();
    return null;
  },

  actions: {
    onToggle() {
      this.get("isExpanded") === true ? this.collapse() : this.expand();
    },

    onCreateContent(input) {
      const content = this.baseOnCreateContent(input);
      this.get("content").pushObject(content);
      this.send("onSelect", content.value);
    },

    onFilterChange(_filter) {
      if (this.get("filterable") === false && this.get("autoFilterable") === false) {
        return;
      }

      if (_filter !== this.get("filter")) {
        this.expand();
        this.set("highlightedValue", null);
        this.set("filter", _filter);
        this.set("renderedFilterOnce", true);
      }
    },

    onHighlight(value) {
      value = this.baseOnHighlight(value);
      this.set("highlightedValue", value);
    },

    onClearSelection() {
      this.baseOnClearSelection();
      this.set("value", null);
    },

    onSelect(value) {
      value = this.baseOnSelect(value);
      this.set("value", value);
    },

    onDeselect() {
      this.baseOnDeselect();
      this.set("value", null);
    }
  },

  clearFilter() {
    this.$filterInput().val("");
    this.setProperties({ filter: "" });
  },

  originalValueForValue(value) {
    if (isNone(value)) { return null; }
    if (value === this.noneValue) { return this.noneValue; }

    const computedContent = this.computedContentForValue(value);

    if (isNone(computedContent)) { return value; }

    return get(computedContent.originalContent, this.get("valueAttribute"));
  },

  @on("didReceiveAttrs")
  _mutateValue() {
    if (this.get("allowValueMutation") !== true) {
      return;
    }

    const none = isNone(this.get("none"));
    const emptyValue = isEmpty(this.get("value"));

    if (none && emptyValue) {
      Ember.run.scheduleOnce("sync", () => {
        if (!isEmpty(this.get("computedContent"))) {
          const firstValue = this.get("computedContent.firstObject.value");
          this.set("value", firstValue);
        }
      });
    }
  }
});
