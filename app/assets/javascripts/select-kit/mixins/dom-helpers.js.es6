import { on } from "ember-addons/ember-computed-decorators";

export default Ember.Mixin.create({
  init() {
    this._super();

    this.filterInputSelector = ".filter-input";
    this.rowSelector = ".select-kit-row";
    this.collectionSelector = ".select-kit-collection";
    this.headerSelector = ".select-kit-header";
    this.bodySelector = ".select-kit-body";
    this.wrapperSelector = ".select-kit-wrapper";
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

  $filterInput() { return this.$(this.filterInputSelector); },

  @on("didRender")
  _ajustPosition() {
    $(`.select-kit-fixed-placeholder-${this.elementId}`).remove();
    this.$collection().css("max-height", this.get("collectionHeight"));
    this._applyFixedPosition();
    this._applyDirection();
    this._positionWrapper();
  },

  @on("didInsertElement")
  _setupResizeListener() {
    $(window).on("resize.select-kit", () => this.collapse() );
  },

  @on("willDestroyElement")
  _clearState() {
    $(window).off("resize.select-kit");
    $(`.select-kit-fixed-placeholder-${this.elementId}`).remove();
  },

  // use to collapse and remove focus
  close(event) {
    this.collapse(event);
    this.setProperties({ isFocused: false });
  },

  // force the component in a known default state
  focus() {
    Ember.run.schedule("afterRender", () => this.$header().focus());
  },

  expand() {
    if (this.get("isExpanded") === true) return;
    this.setProperties({ isExpanded: true, renderedBodyOnce: true, isFocused: true });

    Ember.run.schedule("afterRender", () => {
      if (this.$filterInput().is(":visible")) {
        this.$filterInput().focus();
      } else {
        this.$header().focus();
      }
    });

    this.autoHighlight();
  },

  collapse() {
    this.set("isExpanded", false);
    Ember.run.schedule("afterRender", () => this._removeFixedPosition() );
  },

  // lose focus of the component in two steps
  // first collapse and keep focus and then remove focus
  unfocus(event) {
    if (this.get("isExpanded") === true) {
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

    const dHeader = $(".d-header")[0];
    const dHeaderBounds = dHeader ? dHeader.getBoundingClientRect() : {top: 0, height: 0};
    const dHeaderHeight = dHeaderBounds.top + dHeaderBounds.height;
    const componentHeight = this.$().outerHeight(false);
    const componentWidth = this.$().outerWidth(false);
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
          options.right = - (bodyWidth - componentWidth + this.get("horizontalOffset"));
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

    const fullHeight = this.get("verticalOffset") + bodyHeight + componentHeight;
    const hasBelowSpace = windowHeight - offsetBottom - fullHeight > 0;
    const hasAboveSpace = offsetTop - fullHeight - dHeaderHeight > 0;
    if (hasBelowSpace || (!hasBelowSpace && !hasAboveSpace)) {
      this.setProperties({ isBelow: true, isAbove: false });
      options.top = componentHeight + this.get("verticalOffset") - 2;
    } else {
      this.setProperties({ isBelow: false, isAbove: true });
      options.bottom = componentHeight + this.get("verticalOffset") - 1;
    }

    this.$body().css(options);
  },

  _applyFixedPosition() {
    if (this.get("isExpanded") !== true) { return; }

    const scrollableParent = this.$().parents(this.get("scrollableParentSelector"));
    if (scrollableParent.length === 0) { return; }

    const width = this.$().outerWidth(false);
    const height = this.$().outerHeight(false);
    const $placeholder = $(`<div class='select-kit-fixed-placeholder-${this.elementId}'></div>`);

    this._previousScrollParentOverflow = this._previousScrollParentOverflow || scrollableParent.css("overflow");
    scrollableParent.css({ overflow: "hidden" });

    this._previousCSSContext = {
      minWidth: this.$().css("min-width"),
      maxWidth: this.$().css("max-width")
    };

    const componentStyles = {
      position: "fixed",
      "margin-top": -scrollableParent.scrollTop(),
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
    $(`.select-kit-fixed-placeholder-${this.elementId}`).remove();

    if (!this.element || this.isDestroying || this.isDestroyed) { return; }

    const scrollableParent = this.$().parents(this.get("scrollableParentSelector"));
    if (scrollableParent.length === 0) { return; }

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

    scrollableParent.css("overflow", this._previousScrollParentOverflow);
  },

  _positionWrapper() {
    const componentHeight = this.$().outerHeight(false);

    this.$(this.wrapperSelector).css({
      width: this.$().outerWidth(false) - 2,
      height: componentHeight + this.$body().outerHeight(false)
    });
  },
});
