const { get, isNone, isEmpty, isPresent } = Ember;
import { on, observes } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";
import DomHelpersMixin from "select-box-kit/mixins/dom-helpers";
import KeyboardMixin from "select-box-kit/mixins/keyboard";

export default Ember.Component.extend(DomHelpersMixin, KeyboardMixin, {
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
  headerCaretUpIcon: "caret-up",
  headerCaretDownIcon: "caret-down",
  headerIcon: null,
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

  focusOutFromOffscreen(event) {
    if (this.get("isExpanded") === false && this.get("isFocused") === true) {
      this.close();
    }
  },

  clickOutside(event) {
    if (this.get("isExpanded") === true) {
      this.set("isExpanded", false);
    } else {
      this.close();
    }
  },

  focusOutFromFilterInput(event) {
    setTimeout(() => {
      const focusedOutOfComponent = document.activeElement !== this.$offscreenInput()[0];
      if (focusedOutOfComponent) {

        if (this.get("isExpanded") === true) {
          this.set("isExpanded", false);
          this.$offscreenInput().focus();
        }
      }
    }, 10);
  },

  init() {
    this._super();

    if ($(window).outerWidth(false) <= 420) {
      this.setProperties({ filterable: false, autoFilterable: false });
    }
  },

  close() {
    this.setProperties({ isExpanded: false, isFocused: false });
  },

  createFunction(input) {
    return (selectedBox) => {
      const formatedContent = selectedBox.formatContent(input);
      formatedContent.meta.generated = true;
      return formatedContent;
    };
  },

  filterFunction(content) {
    return selectBox => {
      const filter = selectBox.get("filter").toLowerCase();
      return _.filter(content, c => {
        return get(c, "name").toLowerCase().indexOf(filter) > -1;
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
      return this._castInteger(content);
    default:
      return this._castInteger(get(content, this.get("valueAttribute")));
    }
  },

  formatContent(content) {
    return {
      value: this.valueForContent(content),
      name: this.nameForContent(content),
      originalContent: content,
      meta: {
        generated: false
      }
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
    return computedFilterable === true && filter.length > 0 && allow === true;
  },

  @computed("filter", "allowAny")
  createRowContent(filter, allow) {
    if (allow === true) {
      return Ember.Object.create({ value: filter, name: filter });
    }
  },

  @computed("content.[]")
  computedContent(content) {
    return this.formatContents(content || []);
  },

  @computed("value", "none", "computedContent.firstObject.value")
  computedValue(value, none, firstContentValue) {
    if (isNone(value) && isNone(none)) {
      return this._castInteger(firstContentValue);
    }

    return this._castInteger(value);
  },

  @computed("headerText", "selectedContent.firstObject.name")
  computedHeaderText(headerText, name) {
    return isNone(name) ? I18n.t(headerText).htmlSafe() : name;
  },

  @computed
  titleForRow() {
    return rowComponent => rowComponent.get("content.name");
  },

  @computed("highlightedValue")
  shouldHighlightRow(highlightedValue) {
    return (rowComponent) => {
      return this._castInteger(highlightedValue) === rowComponent.get("content.value");
    };
  },

  @computed
  iconForRow() {
    return rowComponent => {
      const content = rowComponent.get("content");
      if (get(content, "originalContent.icon")) {
        const iconName = get(content, "originalContent.icon");
        const iconClass = get(content, "originalContent.iconClass");
        return iconHTML(iconName, { class: iconClass });
      }

      return null;
    };
  },

  @computed("computedValue")
  shouldSelectRow(computedValue) {
    return rowComponent => computedValue === rowComponent.get("content.value");
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
      return Ember.Object.create({ name: I18n.t(none), value: "none" });
    default:
      return this.formatContent(none);
    }
  },

  @computed("computedValue", "computedContent.[]")
  selectedContent(computedValue, computedContent) {
    if (isNone(computedValue)) {
      return [];
    }

    return [ computedContent.findBy("value", this._castInteger(computedValue)) ];
  },

  @on("didRender")
  _configureSelectBoxDOM() {
    if (this.get("scrollableParent").length === 1) {
      this._removeFixedPosition();
    }

    if (this.get("isExpanded") === true) {
      if (this.get("scrollableParent").length === 1) {
        this._applyFixedPosition(
          this.$().outerWidth(false),
          this.$header().outerHeight(false)
        );
      }

      Ember.run.schedule("afterRender", () => {
        this.$collection().css("max-height", this.get("collectionHeight"));
        this._applyDirection();
        this._positionSelectBoxWrapper();
      });
    }
  },

  @on("willDestroyElement")
  _removeResizeListener() {
    $(window).off(`resize.${this.elementId}`);
  },

  @on("willDestroyElement")
  _removeResizeListener() {
    this._removeFixedPosition();
  },

  @on("didInsertElement")
  _setupResizeListener() {
    $(window).on(`resize.${this.elementId}`, () => this.set("isExpanded", false) );
  },

  @on("didInsertElement")
  _setupScrollListener() {
    this.get("scrollableParent")
      .on(`scroll.${this.elementId}`, () => this.set("isExpanded", false) );
  },

  @observes("filter", "filteredContent.[]", "shouldDisplayCreateRow")
  _setHighlightedValue() {
    const filteredContent = this.get("filteredContent");
    const display = this.get("shouldDisplayCreateRow");
    const none = this.get("computedNone");

    if (isNone(this.get("highlightedValue")) && !isEmpty(filteredContent)) {
      this.set("highlightedValue", get(filteredContent, "firstObject.value"));
      return;
    }

    if (display === true && isEmpty(filteredContent)) {
      this.set("highlightedValue", this.get("filter"));
    }
    else if (!isEmpty(filteredContent)) {
      this.set("highlightedValue", get(filteredContent, "firstObject.value"));
    }
    else if (isEmpty(filteredContent) && isPresent(none) && display === false) {
      this.set("highlightedValue", get(none, "value"));
    }
  },

  @observes("isExpanded")
  _isExpandedChanged() {
    if (this.get("isExpanded") === true) {
      this.setProperties({ highlightedValue: null, renderBody: true, isFocused: true });
    }
  },

  @computed("highlightedValue", "computedContent.[]")
  highlightedContent(highlightedValue, computedContent) {
    if (isNone(highlightedValue)) {
      return null;
    }

    return computedContent.find(c => get(c, "value") === highlightedValue );
  },

  @computed("filter", "computedFilterable", "computedContent.[]", "computedValue.[]")
  filteredContent(filter, computedFilterable, computedContent, computedValue) {
    if (computedFilterable === false) {
      return computedContent;
    }

    return this.filterFunction(computedContent)(this, computedValue);
  },

  @computed("scrollableParentSelector")
  scrollableParent(scrollableParentSelector) {
    return this.$().parents(scrollableParentSelector).first();
  },

  actions: {
    onToggle() {
      this.toggleProperty("isExpanded");

      if (this.get("isExpanded") === true) {
        this.$offscreenInput().focus();
      }
    },

    onCreateContent(input) {
      const content = this.createFunction(input)(this);
      this.get("computedContent").pushObject(content);
      this.send("onSelect", content.value);
    },

    onFilterChange(filter) {
      this.set("filter", filter);
    },

    onHighlight(value) {
      this.set("highlightedValue", value);
    },

    onClearSelection() {
      this.defaultOnSelect();
      this.set("value", null);
    },

    onSelect(value) {
      this.defaultOnSelect();
      this.set("value", value);
    },

    onDeselect() {
      this.defaultOnDeselect();
      this.set("value", null);
    }
  },

  _positionSelectBoxWrapper() {
    const headerHeight = this.$header().outerHeight(false);

    this.$(".select-box-kit-wrapper").css({
      width: this.$().width(),
      height: headerHeight + this.$body().outerHeight(false)
    });
  },

  _castInteger(value) {
    if (this.get("castInteger") === true && isPresent(value)) {
      return parseInt(value, 10);
    }

    return isNone(value) ? value : value.toString();
  },

  _applyFixedPosition(width, height) {
    const $placeholder = $(`<div class='select-box-kit-fixed-placeholder-${this.elementId}'></div>`);

    this.$()
      .before($placeholder.css({
        display: "inline-block",
        width,
        height,
        "vertical-align": "middle"
      }))
      .css({
        width,
        direction: $("html").css("direction"),
        position: "fixed",
        "margin-top": -this.get("scrollableParent").scrollTop(),
        "margin-left": -width
      });
  },

  defaultOnSelect() {
    this.setProperties({
      highlightedValue: null,
      isExpanded: false,
      filter: ""
    });

    Ember.run.schedule("afterRender", () => {
      this.$offscreenInput().focus();
    });
  },

  defaultOnDeselect(value) {
    const content = this.get("computedContent").findBy("value", value);
    if (!isNone(content) && get(content, "meta.generated") === true) {
      this.get("computedContent").removeObject(content);
    }
  },

  _applyDirection() {
    let options = { left: "auto", bottom: "auto", top: "auto" };
    const headerHeight = this.$header().outerHeight(false);
    const filterHeight = this.$(".select-box-kit-filter").outerHeight(false);
    const bodyHeight = this.$body().outerHeight(false);
    const windowWidth = $(window).width();
    const windowHeight = $(window).height();
    const boundingRect = this.$()[0].getBoundingClientRect();
    const offsetTop = boundingRect.top;

    if (this.get("fullWidthOnMobile") && windowWidth <= 420) {
      const margin = 10;
      const relativeLeft = this.$().offset().left - $(window).scrollLeft();
      options.left = margin - relativeLeft;
      options.width = windowWidth - margin * 2;
      options.maxWidth = options.minWidth = "unset";
    } else {
      const offsetLeft = boundingRect.left;
      const bodyWidth = this.$body().outerWidth(false);
      const hasRightSpace = (windowWidth - (this.get("horizontalOffset") + offsetLeft + filterHeight + bodyWidth) > 0);

      if (hasRightSpace) {
        this.setProperties({ isLeftAligned: true, isRightAligned: false });
        options.left = this.get("horizontalOffset");
      } else {
        this.setProperties({ isLeftAligned: false, isRightAligned: true });
        options.right = this.get("horizontalOffset");
      }
    }

    const componentHeight = this.get("verticalOffset") + bodyHeight + headerHeight;
    const hasBelowSpace = windowHeight - offsetTop - componentHeight > 0;
    if (hasBelowSpace) {
      this.setProperties({ isBelow: true, isAbove: false });
      options.top = headerHeight + this.get("verticalOffset");
    } else {
      this.setProperties({ isBelow: false, isAbove: true });
      options.bottom = headerHeight + this.get("verticalOffset");
    }

    this.$body().css(options);
  },

  _removeFixedPosition() {
    $(`.select-box-kit-fixed-placeholder-${this.elementId}`).remove();

    this.$().css({
      top: "auto",
      left: "auto",
      "margin-left": "auto",
      "margin-top": "auto",
      position: "relative"
    });

    this.get("scrollableParent").off(`scroll.${this.elementId}`);
  }
});
