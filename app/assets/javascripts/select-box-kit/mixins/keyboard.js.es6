const { isEmpty } = Ember;

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
      .off("keydown.select-box-kit");

    this.$filterInput().off("keydown.select-box-kit");
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

        switch (keyCode) {
          case this.keys.UP:
          case this.keys.DOWN:
            if (this.get("isExpanded") === false) {
              this.set("isExpanded", true);
            }

            Ember.run.schedule("actions", () => {
              this._handleArrowKey(keyCode);
            });

            this._killEvent(event);

            return;
          case this.keys.ENTER:
            if (this.get("isExpanded") === false) {
              this.set("isExpanded", true);
            } else {
              this.send("onSelect", this.$highlightedRow().data("value"));
            }

            this._killEvent(event);

            return;
          case this.keys.TAB:
            if (this.get("isExpanded") === false) {
              return true;
            } else {
              this.send("onSelect", this.$highlightedRow().data("value"));
              return;
            }
          case this.keys.ESC:
            this.close();
            this._killEvent(event);
            return;
          case this.keys.BACKSPACE:
            this._killEvent(event);
            return;
        }

        if (this._isSpecialKey(keyCode) === false && event.metaKey === false) {
          this.setProperties({
            isExpanded: true,
            filter: String.fromCharCode(keyCode)
          });

          Ember.run.schedule("afterRender", () => this.$filterInput().focus() );
        }
      });

    this.$filterInput()
      .on(`keydown.select-box-kit`, (event) => {
        const keyCode = event.keyCode || event.which;

        if ([
            this.keys.RIGHT,
            this.keys.LEFT,
            this.keys.BACKSPACE,
            this.keys.SPACE,
          ].includes(keyCode) || event.metaKey === true) {
          return true;
        }

        if (this._isSpecialKey(keyCode) === true) {
          this.$offscreenInput().focus().trigger(event);
        }

        return true;
      });
  },

  _handleArrowKey(keyCode) {
    if (isEmpty(this.get("filteredContent"))) {
      return;
    }

    Ember.run.schedule("afterRender", () => {
      switch (keyCode) {
        case 38:
          Ember.run.throttle(this, this._handleUpArrow, 32);
          break;
        default:
          Ember.run.throttle(this, this._handleDownArrow, 32);
      }
    });
  },

  _moveHighlight(direction) {
    const $rows = this.$rows();
    const currentIndex = $rows.index(this.$highlightedRow());

    let nextIndex = 0;

    if (currentIndex < 0) {
      nextIndex = 0;
    } else if (currentIndex + direction < $rows.length) {
      nextIndex = currentIndex + direction;
    }

    this._rowSelection($rows, nextIndex);
  },

  _handleDownArrow() { this._moveHighlight(1); },

  _handleUpArrow() { this._moveHighlight(-1); },

  _rowSelection($rows, nextIndex) {
    const highlightableValue = $rows.eq(nextIndex).data("value");
    const $highlightableRow = this.$findRowByValue(highlightableValue);
    this.send("onHighlight", highlightableValue);

    Ember.run.schedule("afterRender", () => {
      const $collection = this.$collection();
      const currentOffset = $collection.offset().top +
                            $collection.outerHeight(false);
      const nextBottom = $highlightableRow.offset().top +
                         $highlightableRow.outerHeight(false);
      const nextOffset = $collection.scrollTop() + nextBottom - currentOffset;

      if (nextIndex === 0) {
        $collection.scrollTop(0);
      } else if (nextBottom > currentOffset) {
        $collection.scrollTop(nextOffset);
      }
    });
  },

  _isSpecialKey(keyCode) {
    return _.values(this.keys).includes(keyCode);
  },
});
