const { get, isNone, isEmpty, isPresent } = Ember;
import { on, observes } from "ember-addons/ember-computed-decorators";
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

  init() {
    this._super();

    if ($(window).outerWidth(false) <= 420) {
      this.setProperties({ filterable: false, autoFilterable: false });
    }

    this._previousScrollParentOverflow = "auto";
    this._previousCSSContext = {};
  },

  close() {
    this.setProperties({ isExpanded: false, isFocused: false });
  },

  focus() {
    Ember.run.schedule("afterRender", () => this.$offscreenInput().select() );
  },

  blur() {
    Ember.run.schedule("afterRender", () => this.$offscreenInput().blur() );
  },

  clickOutside(event) {
    if ($(event.target).parents(".select-box-kit").length === 1) {
      this.close();
      return;
    }

    if (this.get("isExpanded") === true) {
      this.set("isExpanded", false);
      this.focus();
    } else {
      this.close();
    }
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
      meta: { generated: false }
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
      return Ember.Object.create({ name: I18n.t(none), value: "" });
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
    if (this.get("isExpanded") === true) {
      Ember.run.schedule("afterRender", () => {
        this.$collection().css("max-height", this.get("collectionHeight"));
        this._applyDirection();
        this._positionWrapper();
      });
    }
  },

  @on("willDestroyElement")
  _cleanHandlers() {
    $(window).off("resize.select-box-kit");
    this._removeFixedPosition();
  },

  @on("didInsertElement")
  _setupResizeListener() {
    $(window).on("resize.select-box-kit", () => this.set("isExpanded", false) );
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
      this._applyFixedPosition();

      this.setProperties({
        highlightedValue: this.get("computedValue"),
        renderBody: true,
        isFocused: true
      });
    } else {
      this._removeFixedPosition();
    }
  },

  @computed("filter", "computedFilterable", "computedContent.[]", "computedValue.[]")
  filteredContent(filter, computedFilterable, computedContent, computedValue) {
    if (computedFilterable === false) { return computedContent; }
    return this.filterFunction(computedContent)(this, computedValue);
  },

  @computed("scrollableParentSelector")
  scrollableParent(scrollableParentSelector) {
    return this.$().parents(scrollableParentSelector).first();
  },

  actions: {
    onToggle() {
      this.toggleProperty("isExpanded");

      if (this.get("isExpanded") === true) { this.focus(); }
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
      this.send("onSelect", null);
    },

    onSelect(value) {
      value = this.defaultOnSelect(value);
      this.set("value", value);
    },

    onDeselect() {
      this.defaultOnDeselect();
      this.set("value", null);
    }
  },

  defaultOnSelect(value) {
    if (value === "") { value = null; }

    this.setProperties({
      highlightedValue: null,
      isExpanded: false,
      filter: ""
    });

    this.focus();

    return value;
  },

  defaultOnDeselect(value) {
    const content = this.get("computedContent").findBy("value", value);
    if (!isNone(content) && get(content, "meta.generated") === true) {
      this.get("computedContent").removeObject(content);
    }
  },

  _applyDirection() {
    let options = { left: "auto", bottom: "auto", top: "auto" };

    const dHeader = $(".d-header")[0];
    const dHeaderBounds = dHeader ? dHeader.getBoundingClientRect() : {top: 0, height: 0};
    const dHeaderHeight = dHeaderBounds.top + dHeaderBounds.height;
    const headerHeight = this.$header().outerHeight(false);
    const headerWidth = this.$header().outerWidth(false);
    const bodyHeight = this.$body().outerHeight(false);
    const windowWidth = $(window).width();
    const windowHeight = $(window).height();
    const boundingRect = this.get("element").getBoundingClientRect();
    const offsetTop = boundingRect.top;
    const offsetBottom = boundingRect.bottom;

    if (this.get("fullWidthOnMobile") && windowWidth <= 420) {
      const margin = 10;
      const relativeLeft = this.$().offset().left - $(window).scrollLeft();
      options.left = margin - relativeLeft;
      options.width = windowWidth - margin * 2;
      options.maxWidth = options.minWidth = "unset";
    } else {
      const bodyWidth = this.$body().outerWidth(false);

      if ($("html").css("direction") === "rtl") {
        const horizontalSpacing = boundingRect.right;
        const hasHorizontalSpace = horizontalSpacing - (this.get("horizontalOffset") + bodyWidth) > 0;
        if (hasHorizontalSpace) {
          this.setProperties({ isLeftAligned: true, isRightAligned: false });
          options.left = bodyWidth + this.get("horizontalOffset");
        } else {
          this.setProperties({ isLeftAligned: false, isRightAligned: true });
          options.right = - (bodyWidth - headerWidth + this.get("horizontalOffset"));
        }
      } else {
        const horizontalSpacing = boundingRect.left;
        const hasHorizontalSpace = (windowWidth - (this.get("horizontalOffset") + horizontalSpacing + bodyWidth) > 0);
        if (hasHorizontalSpace) {
          this.setProperties({ isLeftAligned: true, isRightAligned: false });
          options.left = this.get("horizontalOffset");
        } else {
          this.setProperties({ isLeftAligned: false, isRightAligned: true });
          options.right = this.get("horizontalOffset");
        }
      }
    }

    const componentHeight = this.get("verticalOffset") + bodyHeight + headerHeight;
    const hasBelowSpace = windowHeight - offsetBottom - componentHeight > 0;
    const hasAboveSpace = offsetTop - componentHeight - dHeaderHeight > 0;
    if (hasBelowSpace || (!hasBelowSpace && !hasAboveSpace)) {
      this.setProperties({ isBelow: true, isAbove: false });
      options.top = headerHeight + this.get("verticalOffset");
    } else {
      this.setProperties({ isBelow: false, isAbove: true });
      options.bottom = headerHeight + this.get("verticalOffset");
    }

    this.$body().css(options);
  },

  _applyFixedPosition() {
    const width = this.$().outerWidth(false);
    const height = this.$header().outerHeight(false);

    if (this.get("scrollableParent").length === 0) { return; }

    const $placeholder = $(`<div class='select-box-kit-fixed-placeholder-${this.elementId}'></div>`);

    this._previousScrollParentOverflow = this.get("scrollableParent").css("overflow");
    this.get("scrollableParent").css({ overflow: "hidden" });

    this._previousCSSContext = {
      minWidth: this.$().css("min-width"),
      maxWidth: this.$().css("max-width")
    };

    const componentStyles = {
      position: "fixed",
      "margin-top": -this.get("scrollableParent").scrollTop(),
      width,
      minWidth: "unset",
      maxWidth: "unset"
    };

    if ($("html").css("direction") === "rtl") {
      componentStyles.marginRight = -width;
    } else {
      componentStyles.marginLeft = -width;
    }

    $placeholder.css({ display: "inline-block", width, height, "vertical-align": "middle" });

    this.$().before($placeholder).css(componentStyles);
  },

  _removeFixedPosition() {
    if (this.get("scrollableParent").length === 0) {
      return;
    }

    $(`.select-box-kit-fixed-placeholder-${this.elementId}`).remove();

    const css = _.extend(
      this._previousCSSContext,
      {
        top: "auto",
        left: "auto",
        "margin-left": "auto",
        "margin-right": "auto",
        "margin-top": "auto",
        position: "relative"
      }
    );
    this.$().css(css);

    this.get("scrollableParent").css({
      overflow: this._previousScrollParentOverflow
    });
  },

  _positionWrapper() {
    const headerHeight = this.$header().outerHeight(false);

    this.$(".select-box-kit-wrapper").css({
      width: this.$().width(),
      height: headerHeight + this.$body().outerHeight(false)
    });
  },

  @on("didReceiveAttrs")
  _mutateValue() {
    if (this.get("allowValueMutation") !== true) {
      return;
    }

    const none = isNone(this.get("none"));
    const emptyValue = isEmpty(this.get("value"));
    const notEmptyContent = !isEmpty(this.get("content"));

    if (none && emptyValue && notEmptyContent) {
      Ember.run.scheduleOnce("sync", () => {
        const firstValue = this.get(`content.0.${this.get("valueAttribute")}`);
        this.set("value", firstValue);
      });
    }
  }
});
