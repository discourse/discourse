const { get, isNone, isEmpty, isPresent } = Ember;
import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import UtilsMixin from "select-box-kit/mixins/utils";
import DomHelpersMixin from "select-box-kit/mixins/dom-helpers";
import KeyboardMixin from "select-box-kit/mixins/keyboard";

const NONE_VALUE = "__none__";

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
  renderBody: false,
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
  _filter: "",
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

    if ($(window).outerWidth(false) <= 420) {
      this.setProperties({ filterable: false, autoFilterable: false });
    }

    this._previousScrollParentOverflow = "auto";
    this._previousCSSContext = {};

    this.set("content", this.getWithDefault("content", []));
  },

  @on("didReceiveAttrs")
  _setInitialValues() {
    this.set("_initialValues", this.get("content").map((c) => {
      return this.valueForContent(c);
    }));
  },

  click(event) {
    event.stopPropagation();
  },

  close() {
    this.setProperties({ isExpanded: false, isFocused: false });
  },

  focus() {
    Ember.run.schedule("afterRender", () => this.$offscreenInput().select() );
  },

  expand() {
    this.setProperties({ isExpanded: true, renderBody: true, isFocused: true });
  },

  @on("didRender")
  _ajustPosition() {
    this._applyFixedPosition();
    this._applyDirection();
    this._positionWrapper();
  },

  collapse() {
    this.set("isExpanded", false);
    Ember.run.schedule("afterRender", () => this._removeFixedPosition() );
  },

  unfocus() {
    this.set("highlightedValue", null);

    if (this.get("isExpanded") === true) {
      this.collapse();
      this.focus();
    } else {
      this.close();
    }
  },

  blur() {
    Ember.run.schedule("afterRender", () => this.$offscreenInput().blur() );
  },

  clickOutside(event) {
    if ($(event.target).parents(".select-box-kit").length === 1) {
      this.close();
      return;
    }

    this.unfocus();
  },

  createFunction(input) {
    return (selectedBox) => selectedBox.formatContent(input);
  },

  filterFunction(content) {
    return selectBox => {
      const filter = selectBox.get("filter").toLowerCase();
      return _.filter(content, c => {
        return get(c, "name").toString().toLowerCase().indexOf(filter) > -1;
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

  formatContent(content) {
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
      originalContent
    };
  },

  formatContents(contents) {
    return contents.map(content => this.formatContent(content));
  },

  @computed("filter", "filterable", "autoFilterable")
  computedFilterable(filter, filterable, autoFilterable) {
    if (filterable === true) {
      return true;
    }

    if (filter.length > 0 && autoFilterable === true) {
      return true;
    }

    return false;
  },

  @computed("computedFilterable", "filter", "allowAny")
  shouldDisplayCreateRow(computedFilterable, filter, allow) {
    return filter.length > 0 && allow === true;
  },

  @computed("filter", "allowAny")
  createRowContent(filter, allow) {
    if (allow === true) {
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
    if (isNone(none)) {
      return null;
    }

    switch (typeof none) {
    case "string":
      return Ember.Object.create({ name: I18n.t(none), value: NONE_VALUE });
    default:
      return this.formatContent(none);
    }
  },

  @computed("computedValue", "computedContent.[]")
  selectedContent(computedValue, computedContent) {
    if (isNone(computedValue)) { return []; }
    return [ computedContent.findBy("value", this._castInteger(computedValue)) ];
  },

  @on("willDestroyElement")
  _cleanHandlers() {
    $(window).off("resize.select-box-kit");
    this._removeFixedPosition();
  },

  @on("didInsertElement")
  _setupResizeListener() {
    this.$collection().css("max-height", this.get("collectionHeight"));
    $(window).on("resize.select-box-kit", () => this.collapse() );
  },

  @on("willRender")
  _autoHighlight() {
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

  @computed("filter", "computedFilterable", "computedContent.[]", "computedValue.[]")
  filteredContent(filter, computedFilterable, computedContent, computedValue) {
    return this.filterFunction(computedContent)(this, computedValue);
  },

  @computed("scrollableParentSelector")
  scrollableParent(scrollableParentSelector) {
    return this.$().parents(scrollableParentSelector).first();
  },

  actions: {
    onSort() {},

    onToggle() {
      if (this.get("isExpanded") === true) {
        this.collapse();
      } else {
        this.expand();
      }
    },

    onCreateContent(input) {
      const content = this.createFunction(input)(this);
      this.get("content").pushObject(content);
      this.send("onSelect", content.value);
    },

    onFilterChange(_filter) {
      if (_filter !== this.get("filter")) {
        this.expand();
        this.set("highlightedValue", null);
        this.set("filter", _filter);
      }
    },

    onHighlight(value) {
      this.set("highlightedValue", value);
    },

    onClearSelection() {
      this.send("onSelect", null);
    },

    onSelect() {
      this.clearFilter();
      this.set("highlightedValue", null);
    },

    onDeselect() {
      this.defaultOnDeselect();
      this.set("value", null);
    }
  },

  clearFilter() {
    this.$filterInput().val("");
    this.setProperties({ filter: "", _filter: "" });
  },

  originalValueForValue(value) {
    if (isNone(value)) { return null; }
    if (value === NONE_VALUE) { return NONE_VALUE; }

    const computedContent = this.computedContentForValue(value);

    if (isNone(computedContent)) { return value; }

    return get(computedContent.originalContent, this.get("valueAttribute"));
  },

  defaultOnSelect(value) {
    if (value === "") { value = null; }

    // this.setProperties({
    //   highlightedValue: null,
    //   isExpanded: false,
    //   filter: ""
    // });
    //
    // this.focus();

    return value;
  },

  defaultOnDeselect(value) {
    const content = this.get("computedContent").findBy("value", value);
    if (!isNone(content)) {
      this.get("computedContent").removeObject(content);
    }
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
