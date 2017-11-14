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

    $(document)
      .off("mousedown.select-kit")
      .off("touchstart.select-kit");

    this.$offscreenInput()
      .off("focus.select-kit")
      .off("focusin.select-kit")
      .off("blur.select-kit")
      .off("keypress.select-kit")
      .off("keydown.select-kit");

    this.$filterInput()
      .off("change.select-kit")
      .off("keydown.select-kit")
      .off("focus.select-kit")
      .off("focusin.select-kit");
  },

  didInsertElement() {
    this._super();

    $(document)
      .on("mousedown.select-kit, touchstart.select-kit", event => {
        if (Ember.isNone(this.get("element"))) {
          return;
        }

        if (this.get("element").contains(event.target)) { return; }
        this.clickOutside(event);
    });

    this.$offscreenInput()
      .on("blur.select-kit", () => {
        if (this.get("isExpanded") === false && this.get("isFocused") === true) {
          this.close();
        }
      })
      .on("focus.select-kit focusin.select-kit", (event) => {
        this.set("isFocused", true);
        this._killEvent(event);
      })
      .on("keydown.select-kit", (event) => {
        const keyCode = event.keyCode || event.which;
        if (keyCode === this.keys.TAB) this.tabFromOffscreen(event);
        if (keyCode === this.keys.BACKSPACE) this.backspaceFromOffscreen(event);
        if (keyCode === this.keys.ESC) this.escapeFromOffscreen(event);
        if (keyCode === this.keys.ENTER) this.enterFromOffscreen(event);
        if ([this.keys.UP, this.keys.DOWN].includes(keyCode)) this.upAndDownFromOffscreen(event);
        return true;
      })
      .on("keypress.select-kit", (event) => {
        const keyCode = event.keyCode || event.which;

        this.expand();

        if (this.get("filterable") === true || this.get("autoFilterable")) {
          this.set("renderedFilterOnce", true);
        }

        Ember.run.schedule("afterRender", () => {
          this.$filterInput()
              .focus()
              .val(this.$filterInput().val() + String.fromCharCode(keyCode));
        });
      });

    this.$filterInput()
      .on("change.select-kit", (event) => {
        this.send("onFilter", $(event.target).val());
      })
      .on("focus.select-kit focusin.select-kit", (event) => {
        this.set("isFocused", true);
        this._killEvent(event);
      })
      .on("keydown.select-kit", (event) => {
        const keyCode = event.keyCode || event.which;

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
      this._killEvent(event);
      Ember.run.throttle(this, this._rowClick, this.$highlightedRow(), 150, 150, true);
      this.focus(event);
    } else {
      this._killEvent(event);
      this.unfocus(event);
    }

    return true;
  },

  didPressEscape(event) {
    this._killEvent(event);
    this.unfocus();
  },

  didPressUpAndDownArrows(event) {
    this._killEvent(event);

    const keyCode = event.keyCode || event.which;

    if (this.get("isExpanded") === false) { this.expand(); }

    const $rows = this.$rows();

    if ($rows.length <= 0) { return; }
    if ($rows.length === 1) {
      this._rowSelection($rows, 0);
      return;
    }

    const direction = keyCode === 38 ? -1 : 1;

    Ember.run.throttle(this, this._moveHighlight, direction, $rows, 32);
  },

  didPressBackspace(event) {
    this._killEvent(event);

    this.expand();

    if (this.$filterInput().is(":visible")) {
      this.$filterInput().focus().trigger(event).trigger("change");
    }
  },

  didPressEnter(event) {
    this._killEvent(event);

    if (this.get("isExpanded") === false) {
      this.expand();
    } else if (this.$highlightedRow().length === 1) {
      Ember.run.throttle(this, this._rowClick, this.$highlightedRow(), 150, true);
    }
  },

  tabFromOffscreen(event) { this.didPressTab(event); },
  tabFromFilter(event) { this.didPressTab(event); },

  escapeFromOffscreen(event) { this.didPressEscape(event); },
  escapeFromFilter(event) { this.didPressEscape(event); },

  upAndDownFromOffscreen(event) { this.didPressUpAndDownArrows(event); },
  upAndDownFromFilter(event) { this.didPressUpAndDownArrows(event); },

  backspaceFromOffscreen(event) { this.didPressBackspace(event); },

  enterFromOffscreen(event) { this.didPressEnter(event); },
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

    Ember.run.schedule("afterRender", () => {
      $highlightableRow.trigger("mouseover").focus();
      this.focus();
    });
  }
});
