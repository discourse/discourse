const { isNone, run, makeArray } = Ember;
import computed from "ember-addons/ember-computed-decorators";
import UtilsMixin from "select-kit/mixins/utils";
import DomHelpersMixin from "select-kit/mixins/dom-helpers";
import KeyboardMixin from "select-kit/mixins/keyboard";
import PluginApiMixin from "select-kit/mixins/plugin-api";
import { applyContentPluginApiCallbacks } from "select-kit/mixins/plugin-api";

export default Ember.Component.extend(UtilsMixin, PluginApiMixin, DomHelpersMixin, KeyboardMixin, {
  pluginApiIdentifiers: ["select-kit"],
  layoutName: "select-kit/templates/components/select-kit",
  classNames: ["select-kit", "select-box-kit"],
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
  none: null,
  highlightedValue: null,
  noContentLabel: "select_kit.no_content",
  valueAttribute: "id",
  nameProperty: "name",
  autoFilterable: false,
  filterable: false,
  filter: "",
  filterPlaceholder: "select_kit.filter_placeholder",
  filterIcon: "search",
  rowComponent: "select-kit/select-kit-row",
  rowComponentOptions: null,
  noneRowComponent: "select-kit/select-kit-none-row",
  createRowComponent: "select-kit/select-kit-create-row",
  filterComponent: "select-kit/select-kit-filter",
  headerComponent: "select-kit/select-kit-header",
  headerComponentOptions: null,
  headerComputedContent: null,
  collectionComponent: "select-kit/select-kit-collection",
  collectionHeight: 200,
  verticalOffset: 0,
  horizontalOffset: 0,
  fullWidthOnMobile: false,
  castInteger: false,
  allowAny: false,
  allowInitialValueMutation: false,
  autoSelectFirst: true,
  content: null,
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

  willComputeAttributes() {},
  didComputeAttributes() {},

  _beforeWillComputeContent(content) { return makeArray(content); },
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

  mutateAttributes() {
    run.next(() => {
      this.mutateContent(this.get("computedContent"));
      this.mutateValue(this.get("computedValue"));
      this.set("headerComputedContent", this.computeHeaderContent());
    });
  },
  mutateContent() {},
  mutateValue(computedValue) { this.set("value", computedValue); },

  computeHeaderContent() {
    return this.baseHeaderComputedContent();
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

  @computed("filter", "filterable", "autoFilterable", "renderedFilterOnce")
  shouldDisplayFilter(filter, filterable, autoFilterable, renderedFilterOnce) {
    return true;
    // if ((renderedFilterOnce === true || filterable === true) && filter.length > 0) { return true; }
    // if (filter.length > 0 && autoFilterable === true) { return true; }
    // return false;
  },

  @computed("filter")
  shouldDisplayCreateRow(filter) {
    if (this.get("allowAny") === true && filter.length > 0) { return true; }
    return false;
  },

  @computed("filter", "shouldDisplayCreateRow")
  createRowComputedContent(filter, shouldDisplayCreateRow) {
    if (shouldDisplayCreateRow === true) {
      let content = this.createContentFromInput(filter);
      return this.computeContentItem(content);
    }
  },

  @computed
  templateForRow() { return () => null; },

  @computed
  templateForNoneRow() { return () => null; },

  @computed("filter")
  templateForCreateRow() {
    return (rowComponent) => {
      return I18n.t("select_box.create", {
        content: rowComponent.get("computedContent.name")
      });
    };
  },

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

    onHighlight(rowComputedContent) {
      this.set("highlightedValue", rowComputedContent.value);
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
