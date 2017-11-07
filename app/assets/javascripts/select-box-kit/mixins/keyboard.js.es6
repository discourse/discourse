export default Ember.Mixin.create({
  init() {
    this._super();

    this.keys = {
      TAB: 9,
      ENTER: 13,
      ESC: 27,
      SPACE: 32,
      LEFT: 37,
      UP: 38,
      RIGHT: 39,
      DOWN: 40,
      SHIFT: 16,
      CTRL: 17,
      ALT: 18,
      PAGE_UP: 33,
      PAGE_DOWN: 34,
      HOME: 36,
      END: 35,
      BACKSPACE: 8
    };
  },

  willDestroyElement() {
    this._super();

    $(document)
      .off("mousedown.select-box-kit")
      .off("touchstart.select-box-kit");

    this.$offscreenInput()
      .off("focus.select-box-kit")
      .off("focusin.select-box-kit")
      .off("blur.select-box-kit")
      .off("keypress.select-box-kit")
      .off("keydown.select-box-kit");

    this.$filterInput()
      .off("keypress.select-box-kit")
      .off("keydown.select-box-kit");
  },

  didInsertElement() {
    this._super();

    $(document)
      .on("mousedown.select-box-kit, touchstart.select-box-kit", event => {
        if (Ember.isNone(this.get("element"))) {
          return;
        }

        if (this.get("element").contains(event.target)) { return; }
        this.clickOutside(event);
    });

    this.$offscreenInput()
      .on("blur.select-box-kit", () => {
        if (this.get("isExpanded") === false && this.get("isFocused") === true) {
          this.close();
        }
      })
      .on("focus.select-box-kit", (event) => {
        this.set("isFocused", true);
        this._killEvent(event);
      })
      .on("focusin.select-box-kit", (event) => {
        this.set("isFocused", true);
        this._killEvent(event);
      })
      .on("keydown.select-box-kit", (event) => {
        const keyCode = event.keyCode || event.which;

        if (keyCode === this.keys.TAB) { this._handleTabOnKeyDown(event); }
        if (keyCode === this.keys.ESC) { this._handleEscOnKeyDown(event); }
        if (keyCode === this.keys.UP || keyCode === this.keys.DOWN) {
          this._handleArrowKey(keyCode, event);
        }

        return true;
      })
      .on("keypress.select-box-kit", (event) => {
        const keyCode = event.keyCode || event.which;

        switch (keyCode) {
          case this.keys.ENTER:
            if (this.get("isExpanded") === false) {
              this.expand();
            } else if (this.$highlightedRow().length === 1) {
              this.$highlightedRow().click();
            }
            return false;
          case this.keys.BACKSPACE:
            return event;
        }

        if (this._isSpecialKey(keyCode) === false && event.metaKey === false) {
          this.expand();
          this.$filterInput()
              .val(this.$filterInput().val() + String.fromCharCode(keyCode))
              .focus();
        }
      });

    this.$filterInput()
      .on("keydown.select-box-kit", (event) => {
        const keyCode = event.keyCode || event.which;

        if (keyCode === this.keys.TAB) { this._handleTabOnKeyDown(event); }
        if (keyCode === this.keys.ESC) { this._handleEscOnKeyDown(event); }
        if (keyCode === this.keys.UP || keyCode === this.keys.DOWN) {
          this._handleArrowKey(keyCode, event);
        }
      })
      .on("change.select-box-kit", () => {
        this.send("onFilterChange", this.$filterInput().val());
      })
      .on("keypress.select-box-kit", (event) => {
        const keyCode = event.keyCode || event.which;

        if ([
            this.keys.RIGHT,
            this.keys.LEFT,
            this.keys.BACKSPACE,
            this.keys.SPACE,
          ].includes(keyCode) || event.metaKey === true) {
          return true;
        }

        if (keyCode === this.keys.TAB && this.get("isExpanded") === false) {
          return true;
        }

        if (this._isSpecialKey(keyCode) === true) {
          this.$offscreenInput().focus().trigger(event);
          return false;
        }

        return true;
      });
  },

  _handleEscOnKeyDown(event) {
    this.unfocus();
    this._killEvent(event);
  },

  _handleTabOnKeyDown(event) {
    if (this.get("isExpanded") === false) {
      this.unfocus();
      return true;
    } else if (this.$highlightedRow().length === 1) {
      this._killEvent(event);
      this.$highlightedRow().click();
      this.$offscreenInput().focus();
    } else {
      this.unfocus();
      return true;
    }
    return false;
  },

  _handleArrowKey(keyCode, event) {
    if (this.get("isExpanded") === false) { this.expand(); }
    this._killEvent(event);
    const $rows = this.$rows();

    if ($rows.length <= 0) { return; }
    if ($rows.length === 1) {
      this._rowSelection($rows, 0);
      return;
    }

    const direction = keyCode === 38 ? -1 : 1;
    Ember.run.throttle(this, this._moveHighlight, direction, $rows, 32);
  },

  _moveHighlight(direction, $rows) {
    const currentIndex = $rows.index(this.$highlightedRow());
    let nextIndex = 0;

    if (currentIndex < 0) {
      nextIndex = 0;
    } else if (currentIndex + direction < $rows.length) {
      nextIndex = currentIndex + direction;
    }

    this._rowSelection($rows, nextIndex);
  },

  _rowSelection($rows, nextIndex) {
    const highlightableValue = $rows.eq(nextIndex).attr("data-value");
    const $highlightableRow = this.$findRowByValue(highlightableValue);
    this.send("onHighlight", highlightableValue);

    Ember.run.schedule("afterRender", () => {
      $highlightableRow.focus();
      this.$filterInput().focus();
    });
  },

  _isSpecialKey(keyCode) {
    return _.values(this.keys).includes(keyCode);
  },
});
