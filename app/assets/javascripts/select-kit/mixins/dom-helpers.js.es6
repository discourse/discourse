import { on } from "ember-addons/ember-computed-decorators";

export default Ember.Mixin.create({
  init() {
    this._super(...arguments);

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

  _adjustPosition() {
    this._applyDirection();
    this._applyFixedPosition();
    this._positionWrapper();
  },

  @on("willDestroyElement")
  _clearState() {
    this.$fixedPlaceholder().remove();
  },

  // use to collapse and remove focus
  close(event) {
    this.setProperties({ isFocused: false });
    this.collapse(event);
  },

  focus() {
    this.focusFilterOrHeader();
  },

  // try to focus filter and fallback to header if not present
  focusFilterOrHeader() {
    const context = this;
    // next so we are sure it finised expand/collapse
    Ember.run.next(() => {
      Ember.run.schedule("afterRender", () => {
        if (
          !context.$filterInput() ||
          !context.$filterInput().is(":visible") ||
          context
            .$filterInput()
            .parent()
            .hasClass("is-hidden")
        ) {
          if (context.$header()) {
            context.$header().focus();
          } else {
            $(context.element).focus();
          }
        } else {
          if (this.site && this.site.isMobileDevice) {
            this.expand();
          } else {
            context.$filterInput().focus();
          }
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

    Ember.run.next(() => {
      this._boundaryActionHandler("onExpand", this);
      Ember.run.schedule("afterRender", () => {
        if (!this.isDestroying && !this.isDestroyed) {
          this._adjustPosition();
        }
      });
    });
  },

  collapse() {
    this.set("isExpanded", false);

    Ember.run.next(() => {
      this._boundaryActionHandler("onCollapse", this);
      Ember.run.schedule("afterRender", () => {
        if (!this.isDestroying && !this.isDestroyed) {
          this._removeFixedPosition();
        }
      });
    });
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

      let spaceToLeftEdge;
      if (this.$scrollableParent().length) {
        spaceToLeftEdge =
          this.$().offset().left - this.$scrollableParent().offset().left;
      } else {
        spaceToLeftEdge = this.get("element").getBoundingClientRect().left;
      }

      let isLeftAligned = true;
      const spaceToRightEdge = parentWidth - spaceToLeftEdge;
      const elementWidth = this.get("element").getBoundingClientRect().width;
      if (spaceToRightEdge > spaceToLeftEdge + elementWidth) {
        isLeftAligned = false;
      }

      if (isLeftAligned) {
        this.$()
          .addClass("is-left-aligned")
          .removeClass("is-right-aligned");

        if (this._isRTL()) {
          options.right = this.get("horizontalOffset");
        } else {
          options.left =
            -bodyWidth + elementWidth - this.get("horizontalOffset");
        }
      } else {
        this.$()
          .addClass("is-right-aligned")
          .removeClass("is-left-aligned");

        if (this._isRTL()) {
          options.right =
            -bodyWidth + elementWidth - this.get("horizontalOffset");
        } else {
          options.left = this.get("horizontalOffset");
        }
      }
    }

    const fullHeight =
      this.get("verticalOffset") + bodyHeight + componentHeight;
    const hasBelowSpace = $(window).height() - offsetBottom - fullHeight >= -1;
    const hasAboveSpace = offsetTop - fullHeight - discourseHeaderHeight >= -1;
    const headerHeight = this._computedStyle(this.$header()[0], "height");

    if (hasBelowSpace || (!hasBelowSpace && !hasAboveSpace)) {
      this.$()
        .addClass("is-below")
        .removeClass("is-above");
      options.top = headerHeight + this.get("verticalOffset");
    } else {
      this.$()
        .addClass("is-above")
        .removeClass("is-below");
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
      "margin-bottom": this.$().css("margin-bottom"),
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
