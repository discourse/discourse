import { next } from "@ember/runloop";
import { schedule } from "@ember/runloop";
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
    this.fixedPlaceholderSelector = `.select-kit-fixed-placeholder-${this.elementId}`;
  },

  $findRowByValue(value) {
    return $(
      this.element.querySelector(`${this.rowSelector}[data-value='${value}']`)
    );
  },

  $header() {
    return $(this.element && this.element.querySelector(this.headerSelector));
  },

  $body() {
    return $(this.element && this.element.querySelector(this.bodySelector));
  },

  $wrapper() {
    return $(this.element && this.element.querySelector(this.wrapperSelector));
  },

  $collection() {
    return $(
      this.element && this.element.querySelector(this.collectionSelector)
    );
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
    return $(
      this.element && this.element.querySelector(this.filterInputSelector)
    );
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
    next(() => {
      schedule("afterRender", () => {
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
    if (this.isExpanded) return;

    this.setProperties({
      isExpanded: true,
      renderedBodyOnce: true,
      isFocused: true
    });
    this.focusFilterOrHeader();
    this.autoHighlight();

    next(() => {
      this._boundaryActionHandler("onExpand", this);
      schedule("afterRender", () => {
        if (!this.isDestroying && !this.isDestroyed) {
          this._adjustPosition();
        }
      });
    });
  },

  collapse() {
    if (!this.isExpanded) return;

    this.set("isExpanded", false);

    next(() => {
      this._boundaryActionHandler("onCollapse", this);
      schedule("afterRender", () => {
        if (!this.isDestroying && !this.isDestroyed) {
          this._removeFixedPosition();
        }
      });
    });
  },

  // lose focus of the component in two steps
  // first collapse and keep focus and then remove focus
  unfocus(event) {
    if (this.isExpanded) {
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
    const componentHeight = this._computedStyle(this.element, "height");
    const offsetTop = this.element.getBoundingClientRect().top;
    const offsetBottom = this.element.getBoundingClientRect().bottom;
    const windowWidth = $(window).width();

    if (this.fullWidthOnMobile && (this.site && this.site.isMobileDevice)) {
      const margin = 10;
      const relativeLeft =
        $(this.element).offset().left - $(window).scrollLeft();
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
          $(this.element).offset().left -
          this.$scrollableParent().offset().left;
      } else {
        spaceToLeftEdge = this.element.getBoundingClientRect().left;
      }

      let isLeftAligned = true;
      const spaceToRightEdge = parentWidth - spaceToLeftEdge;
      const elementWidth = this.element.getBoundingClientRect().width;
      if (spaceToRightEdge > spaceToLeftEdge + elementWidth) {
        isLeftAligned = false;
      }

      if (isLeftAligned) {
        this.element.classList.add("is-left-aligned");
        this.element.classList.remove("is-right-aligned");

        if (this._isRTL()) {
          options.right = this.horizontalOffset;
        } else {
          options.left = -bodyWidth + elementWidth - this.horizontalOffset;
        }
      } else {
        this.element.classList.add("is-right-aligned");
        this.element.classList.remove("is-left-aligned");

        if (this._isRTL()) {
          options.right = -bodyWidth + elementWidth - this.horizontalOffset;
        } else {
          options.left = this.horizontalOffset;
        }
      }
    }

    const fullHeight = this.verticalOffset + bodyHeight + componentHeight;
    const hasBelowSpace = $(window).height() - offsetBottom - fullHeight >= -1;
    const hasAboveSpace = offsetTop - fullHeight - discourseHeaderHeight >= -1;
    const headerHeight = this._computedStyle(this.$header()[0], "height");

    if (hasBelowSpace || (!hasBelowSpace && !hasAboveSpace)) {
      this.element.classList.add("is-below");
      this.element.classList.remove("is-above");
      options.top = headerHeight + this.verticalOffset;
    } else {
      this.element.classList.add("is-above");
      this.element.classList.remove("is-below");
      options.bottom = headerHeight + this.verticalOffset;
    }

    this.$body().css(options);
  },

  _applyFixedPosition() {
    if (this.isExpanded !== true) return;
    if (this.$fixedPlaceholder().length) return;
    if (!this.$scrollableParent().length) return;

    const width = this._computedStyle(this.element, "width");
    const height = this._computedStyle(this.element, "height");

    this._previousScrollParentOverflow =
      this._previousScrollParentOverflow ||
      this.$scrollableParent().css("overflow");

    this._previousCSSContext = this._previousCSSContext || {
      width,
      minWidth: this.element.style.minWidth,
      maxWidth: this.element.style.maxWidth,
      top: this.element.style.top,
      left: this.element.style.left,
      marginLeft: this.element.style.marginLeft,
      marginRight: this.element.style.marginRight,
      position: this.element.style.position
    };

    const componentStyles = {
      top: this.element.getBoundingClientRect().top,
      width,
      left: this.element.getBoundingClientRect().left,
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
      "margin-bottom": this.element.style.marginBottom,
      "vertical-align": "middle"
    });

    $(this.element)
      .before($placeholderTemplate)
      .css(componentStyles);

    this.$scrollableParent().css({ overflow: "hidden" });
  },

  _removeFixedPosition() {
    this.$fixedPlaceholder().remove();

    if (!this.element || this.isDestroying || this.isDestroyed) return;
    if (this.$scrollableParent().length === 0) return;

    $(this.element).css(this._previousCSSContext || {});
    this.$scrollableParent().css(
      "overflow",
      this._previousScrollParentOverflow || {}
    );
  },

  _positionWrapper() {
    const elementWidth = this._computedStyle(this.element, "width");
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
