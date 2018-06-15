import { on } from "ember-addons/ember-computed-decorators";

export default Ember.Mixin.create({
  init() {
    this._super();

    this._previousScrollParentOverflow = null;
    this._previousCSSContext = null;
    this.selectionSelector = ".choice";
    this.filterInputSelector = ".filter-input";
    this.rowSelector = ".select-kit-row";
    this.collectionSelector = ".select-kit-collection";
    this.headerSelector = ".select-kit-header";
    this.bodySelector = ".select-kit-body";
    this.wrapperSelector = ".select-kit-wrapper";
    this.scrollableParentSelector = ".modal-body";
    this.fixedPlaceholderSelector = `.select-kit-fixed-placeholder-${
      this.elementId
    }`;
  },

  $findRowByValue(value) {
    return this.$(`${this.rowSelector}[data-value='${value}']`);
  },

  $header() {
    return this.$(this.headerSelector);
  },

  $body() {
    return this.$(this.bodySelector);
  },

  $wrapper() {
    return this.$(this.wrapperSelector);
  },

  $collection() {
    return this.$(this.collectionSelector);
  },

  $scrollableParent() {
    return $(this.scrollableParentSelector);
  },

  $fixedPlaceholder() {
    return $(this.fixedPlaceholderSelector);
  },

  $rows() {
    return this.$(`${this.rowSelector}:not(.no-content):not(.is-hidden)`);
  },

  $highlightedRow() {
    return this.$rows().filter(".is-highlighted");
  },

  $selectedRow() {
    return this.$rows().filter(".is-selected");
  },

  $filterInput() {
    return this.$(this.filterInputSelector);
  },

  @on("didRender")
  _adjustPosition() {
    this._applyFixedPosition();
    this._applyDirection();
    this._positionWrapper();
  },

  @on("willDestroyElement")
  _clearState() {
    this.$fixedPlaceholder().remove();
  },

  // use to collapse and remove focus
  close(event) {
    this.collapse(event);
    this.setProperties({ isFocused: false });
  },

  focus() {
    Ember.run.schedule("afterRender", () => {
      this.$header().focus();
    });
  },

  // try to focus filter and fallback to header if not present
  focusFilterOrHeader() {
    const context = this;
    // next so we are sure it finised expand/collapse
    Ember.run.next(() => {
      Ember.run.schedule("afterRender", () => {
        if (
          (this.site && this.site.isMobileDevice) ||
          !context.$filterInput() ||
          !context.$filterInput().is(":visible")
        ) {
          context.$header().focus();
        } else {
          context.$filterInput().focus();
        }
      });
    });
  },

  expand() {
    if (this.get("isExpanded")) return;
    this.setProperties({
      isExpanded: true,
      renderedBodyOnce: true,
      isFocused: true
    });
    this.focusFilterOrHeader();
    this.autoHighlight();
    this._boundaryActionHandler("onExpand", this);
  },

  collapse() {
    this.set("isExpanded", false);
    Ember.run.schedule("afterRender", () => this._removeFixedPosition());
    this._boundaryActionHandler("onCollapse", this);
  },

  // lose focus of the component in two steps
  // first collapse and keep focus and then remove focus
  unfocus(event) {
    if (this.get("isExpanded")) {
      this.collapse(event);
      this.focus(event);
    } else {
      this.close(event);
    }
  },

  _destroyEvent(event) {
    event.preventDefault();
    event.stopPropagation();
  },

  _applyDirection() {
    let options = { left: "auto", bottom: "auto", top: "auto" };

    const discourseHeader = $(".d-header")[0];
    const discourseHeaderHeight = discourseHeader
      ? discourseHeader.getBoundingClientRect().top +
        this._computedStyle(discourseHeader, "height")
      : 0;
    const bodyHeight = this._computedStyle(this.$body()[0], "height");
    const componentHeight = this._computedStyle(this.get("element"), "height");
    const offsetTop = this.get("element").getBoundingClientRect().top;
    const offsetBottom = this.get("element").getBoundingClientRect().bottom;
    const windowWidth = $(window).width();

    if (
      this.get("fullWidthOnMobile") &&
      (this.site && this.site.isMobileDevice)
    ) {
      const margin = 10;
      const relativeLeft = this.$().offset().left - $(window).scrollLeft();
      options.left = margin - relativeLeft;
      options.width = windowWidth - margin * 2;
      options.maxWidth = options.minWidth = "unset";
    } else {
      const parentWidth = this.$scrollableParent().length
        ? this.$scrollableParent().width()
        : windowWidth;
      const bodyWidth = this._computedStyle(this.$body()[0], "width");

      let marginToEdge;
      if (this.$scrollableParent().length) {
        marginToEdge =
          this.$().offset().left - this.$scrollableParent().offset().left;
      } else {
        marginToEdge = this.get("element").getBoundingClientRect().left;
      }

      const enoughMarginToOppositeEdge =
        parentWidth - marginToEdge - bodyWidth + this.get("horizontalOffset") >
        0;
      if (enoughMarginToOppositeEdge) {
        this.setProperties({ isLeftAligned: true, isRightAligned: false });
        options.left = this.get("horizontalOffset");
        options.right = "unset";
      } else {
        this.setProperties({ isLeftAligned: false, isRightAligned: true });
        options.left = "unset";
        options.right = this.get("horizontalOffset");
      }
    }

    const fullHeight =
      this.get("verticalOffset") + bodyHeight + componentHeight;
    const hasBelowSpace = $(window).height() - offsetBottom - fullHeight > 0;
    const hasAboveSpace = offsetTop - fullHeight - discourseHeaderHeight > 0;
    const headerHeight = this._computedStyle(this.$header()[0], "height");
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
    if (this.get("isExpanded") !== true) return;
    if (this.$fixedPlaceholder().length) return;
    if (!this.$scrollableParent().length) return;

    const width = this._computedStyle(this.get("element"), "width");
    const height = this._computedStyle(this.get("element"), "height");

    this._previousScrollParentOverflow =
      this._previousScrollParentOverflow ||
      this.$scrollableParent().css("overflow");

    this._previousCSSContext = this._previousCSSContext || {
      width,
      minWidth: this.$().css("min-width"),
      maxWidth: this.$().css("max-width"),
      top: this.$().css("top"),
      left: this.$().css("left"),
      marginLeft: this.$().css("margin-left"),
      marginRight: this.$().css("margin-right"),
      position: this.$().css("position")
    };

    const componentStyles = {
      top: this.get("element").getBoundingClientRect().top,
      width,
      left: this.get("element").getBoundingClientRect().left,
      marginLeft: 0,
      marginRight: 0,
      minWidth: "unset",
      maxWidth: "unset",
      position: "fixed"
    };

    const $placeholderTemplate = $(
      `<div class='select-kit-fixed-placeholder-${this.elementId}'></div>`
    );
    $placeholderTemplate.css({
      display: "inline-block",
      width,
      height,
      "vertical-align": "middle"
    });

    this.$()
      .before($placeholderTemplate)
      .css(componentStyles);

    this.$scrollableParent().css({ overflow: "hidden" });
  },

  _removeFixedPosition() {
    this.$fixedPlaceholder().remove();

    if (!this.element || this.isDestroying || this.isDestroyed) return;
    if (this.$scrollableParent().length === 0) return;

    this.$().css(this._previousCSSContext || {});
    this.$scrollableParent().css(
      "overflow",
      this._previousScrollParentOverflow || {}
    );
  },

  _positionWrapper() {
    const elementWidth = this._computedStyle(this.get("element"), "width");
    const headerHeight = this._computedStyle(this.$header()[0], "height");
    const bodyHeight = this._computedStyle(this.$body()[0], "height");

    this.$wrapper().css({
      width: elementWidth,
      height: headerHeight + bodyHeight
    });
  },

  _isRTL() {
    return $("html").css("direction") === "rtl";
  },

  _computedStyle(element, style) {
    if (!element) return 0;

    let value;

    if (window.getComputedStyle) {
      value = window.getComputedStyle(element, null)[style];
    } else {
      value = $(element).css(style);
    }

    return this._getFloat(value);
  },

  _getFloat(value) {
    value = parseFloat(value);
    return $.isNumeric(value) ? value : 0;
  }
});
