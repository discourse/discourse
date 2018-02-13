export default Ember.Mixin.create({
  init() {
    this._super();

    this.keys = {
      TAB: 9,
      ENTER: 13,
      ESC: 27,
      UP: 38,
      DOWN: 40,
      BACKSPACE: 8,
    };
  },

  willDestroyElement() {
    this._super();

    $(document).off("mousedown.select-kit");

    if (this.$header()) {
      this.$header()
        .off("blur.select-kit")
        .off("focus.select-kit")
        .off("keypress.select-kit")
        .off("keydown.select-kit");
    }

    if (this.$filterInput()) {
      this.$filterInput()
        .off("change.select-kit")
        .off("keydown.select-kit")
        .off("keypress.select-kit");
    }
  },

  didInsertElement() {
    this._super();

    $(document)
      .on("mousedown.select-kit", event => {
        if (!this.element || this.isDestroying || this.isDestroyed) {
          return true;
        }

        if (Ember.$.contains(this.element, event.target)) {
          event.stopPropagation();
          if (!this.get("renderedBodyOnce")) return;
          if (!this.get("isFocused")) return;
        } else {
          this.didClickOutside(event);
        }

        return true;
    });

    this.$header()
      .on("blur.select-kit", () => {
        if (this.get("isExpanded") === false && this.get("isFocused") === true) {
          this.close();
        }
      })
      .on("focus.select-kit", (event) => {
        this.set("isFocused", true);
        this._destroyEvent(event);
      })
      .on("keydown.select-kit", (event) => {
        const keyCode = event.keyCode || event.which;

        if (document.activeElement !== this.$header()[0]) return event;

        if (keyCode === this.keys.TAB) this.tabFromHeader(event);
        if (keyCode === this.keys.BACKSPACE) this.backspaceFromHeader(event);
        if (keyCode === this.keys.ESC) this.escapeFromHeader(event);
        if (keyCode === this.keys.ENTER) this.enterFromHeader(event);
        if ([this.keys.UP, this.keys.DOWN].includes(keyCode)) this.upAndDownFromHeader(event);
        return event;
      })
      .on("keypress.select-kit", (event) => {
        const keyCode = event.keyCode || event.which;

        if (keyCode === this.keys.ENTER) { return true; }
        if (keyCode === this.keys.TAB) { return true; }

        this.expand(event);

        if (this.get("filterable") === true || this.get("autoFilterable")) {
          this.set("renderedFilterOnce", true);
        }

        if (keyCode >= 65 && keyCode <= 122) {
          Ember.run.schedule("afterRender", () => {
            this.$filterInput()
                .focus()
                .val(this.$filterInput().val() + String.fromCharCode(keyCode));
          });
        }

        return false;
      });

    this.$filterInput()
      .on("change.select-kit", (event) => {
        this.send("filterComputedContent", $(event.target).val());
      })
      .on("keypress.select-kit", (event) => {
        event.stopPropagation();
      })
      .on("keydown.select-kit", (event) => {
        const keyCode = event.keyCode || event.which;

        if (keyCode === this.keys.BACKSPACE && typeof this.backspaceFromFilter === "function") {
          this.backspaceFromFilter(event);
        };
        if (keyCode === this.keys.TAB) this.tabFromFilter(event);
        if (keyCode === this.keys.ESC) this.escapeFromFilter(event);
        if (keyCode === this.keys.ENTER) this.enterFromFilter(event);
        if ([this.keys.UP, this.keys.DOWN].includes(keyCode)) this.upAndDownFromFilter(event);
      });
  },

  didPressTab(event) {
    if (this.get("isExpanded") === false) {
      this.unfocus(event);
    } else if (this.$highlightedRow().length === 1) {
      Ember.run.throttle(this, this._rowClick, this.$highlightedRow(), 150, 150, true);
      this.unfocus(event);
      return true;
    } else {
      this._destroyEvent(event);
      this.unfocus(event);
    }

    return true;
  },

  didPressEscape(event) {
    this._destroyEvent(event);
    this.unfocus(event);
  },

  didPressUpAndDownArrows(event) {
    this._destroyEvent(event);

    const keyCode = event.keyCode || event.which;
    const $rows = this.$rows();

    if (this.get("isExpanded") === false) {
      this.expand(event);

      if (this.$selectedRow().length === 1) {
        this._highlightRow(this.$selectedRow());
        return;
      }
    }

    if ($rows.length <= 0) { return; }
    if ($rows.length === 1) {
      this._rowSelection($rows, 0);
      return;
    }

    const direction = keyCode === 38 ? -1 : 1;

    Ember.run.throttle(this, this._moveHighlight, direction, $rows, 32);
  },

  didPressBackspace(event) {
    this._destroyEvent(event);

    this.expand(event);

    if (this.$filterInput().is(":visible")) {
      this.$filterInput().focus().trigger(event).trigger("change");
    }
  },

  didPressEnter(event) {
    this._destroyEvent(event);

    if (this.get("isExpanded") === false) {
      this.expand(event);
    } else if (this.$highlightedRow().length === 1) {
      Ember.run.throttle(this, this._rowClick, this.$highlightedRow(), 150, true);
    }
  },

  didClickOutside(event) {
    if ($(event.target).parents(".select-kit").length === 1) {
      this.close(event);
      return false;
    }

    this.close(event);
    return;
  },

  // make sure we don’t propagate a click outside component
  // to avoid closing a modal containing the component for example
  click(event) {
    this._destroyEvent(event);
  },

  tabFromHeader(event) { this.didPressTab(event); },
  tabFromFilter(event) { this.didPressTab(event); },

  escapeFromHeader(event) { this.didPressEscape(event); },
  escapeFromFilter(event) { this.didPressEscape(event); },

  upAndDownFromHeader(event) { this.didPressUpAndDownArrows(event); },
  upAndDownFromFilter(event) { this.didPressUpAndDownArrows(event); },

  backspaceFromHeader(event) { this.didPressBackspace(event); },

  enterFromHeader(event) { this.didPressEnter(event); },
  enterFromFilter(event) { this.didPressEnter(event); },

  _moveHighlight(direction, $rows) {
    const currentIndex = $rows.index(this.$highlightedRow());
    let nextIndex = currentIndex + direction;

    if (nextIndex < 0) {
      nextIndex = $rows.length - 1;
    } else if (nextIndex >= $rows.length) {
      nextIndex = 0;
    }

    this._rowSelection($rows, nextIndex);
  },

  _rowClick($row) { $row.click(); },

  _rowSelection($rows, nextIndex) {
    const highlightableValue = $rows.eq(nextIndex).attr("data-value");
    const $highlightableRow = this.$findRowByValue(highlightableValue);
    this._highlightRow($highlightableRow);
  },

  _highlightRow($row) {
    Ember.run.schedule("afterRender", () => {
      $row.trigger("mouseover").focus();
      this.focus();
    });
  }
});
