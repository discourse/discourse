import { on } from "ember-addons/ember-computed-decorators";

export default Ember.Mixin.create({
  init() {
    this._super();

    this.offscreenInputSelector = ".select-box-kit-offscreen";
    this.filterInputSelector = ".select-box-kit-filter-input";
    this.rowSelector = ".select-box-kit-row";
    this.collectionSelector = ".select-box-kit-collection";
    this.headerSelector = ".select-box-kit-header";
    this.bodySelector = ".select-box-kit-body";
    this.wrapperSelector = ".select-box-kit-wrapper";
  },

  $findRowByValue(value) { return this.$(`${this.rowSelector}[data-value='${value}']`); },

  $header() { return this.$(this.headerSelector); },

  $body() { return this.$(this.bodySelector); },

  $collection() { return this.$(this.collectionSelector); },

  $rows(withHidden) {

    if (withHidden === true) {
      return this.$(`${this.rowSelector}:not(.no-content)`);
    } else {
      return this.$(`${this.rowSelector}:not(.no-content):not(.is-hidden)`);
    }
  },

  $highlightedRow() { return this.$rows().filter(".is-highlighted"); },

  $selectedRow() { return this.$rows().filter(".is-selected"); },

  $offscreenInput() { return this.$(this.offscreenInputSelector); },

  $filterInput() { return this.$(this.filterInputSelector); },

  @on("didRender")
  _ajustPosition() {
    $(`.select-box-kit-fixed-placeholder-${this.elementId}`).remove();
    this.$collection().css("max-height", this.get("collectionHeight"));
    this._applyFixedPosition();
    this._applyDirection();
    this._positionWrapper();
  },

  @on("willDestroyElement")
  _clearState() {
    $(window).off("resize.select-box-kit");
    $(`.select-box-kit-fixed-placeholder-${this.elementId}`).remove();
  },

  // make sure we don’t propagate a click outside component
  // to avoid closing a modal containing the component for example
  click(event) { this._killEvent(event); },

  // use to collapse and remove focus
  close() {
    this.collapse();
    this.setProperties({ isFocused: false });
  },

  // force the component in a known default state
  focus() {
    Ember.run.schedule("afterRender", () => this.$offscreenInput().focus() );
  },

  expand() {
    if (this.get("isExpanded") === true) { return; }
    this.setProperties({ isExpanded: true, renderedBodyOnce: true, isFocused: true });
    this.focus();
    this.autoHighlightFunction();
  },

  collapse() {
    this.set("isExpanded", false);
    Ember.run.schedule("afterRender", () => this._removeFixedPosition() );
  },

  // make sure we close/unfocus the component when clicked outside
  clickOutside(event) {
    if ($(event.target).parents(".select-box-kit").length === 1) {
      this.close();
      return false;
    }

    this.unfocus();
    return;
  },

  // lose focus of the component in two steps
  // first collapase and keep focus and then remove focus
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

  _killEvent(event) {
    event.preventDefault();
    event.stopPropagation();
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
    if (this.get("isExpanded") !== true) { return; }
    if (this.get("scrollableParent").length === 0) { return; }

    const width = this.$().outerWidth(false);
    const height = this.$().outerHeight(false);
    const $placeholder = $(`<div class='select-box-kit-fixed-placeholder-${this.elementId}'></div>`);

    this._previousScrollParentOverflow = this._previousScrollParentOverflow || this.get("scrollableParent").css("overflow");
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
    $(`.select-box-kit-fixed-placeholder-${this.elementId}`).remove();

    if (this.get("scrollableParent").length === 0) {
      return;
    }

    if (!this.element || this.isDestroying || this.isDestroyed) { return; }

    const css = jQuery.extend(
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

    this.$(this.wrapperSelector).css({
      width: this.$().outerWidth(false),
      height: headerHeight + this.$body().outerHeight(false)
    });
  },
});
