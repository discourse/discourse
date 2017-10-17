export default Ember.Mixin.create({
  init() {
    this._super();

    this.specialKeys = {
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

    $(document).off(`click.select-box-kit-${this.elementId}`);

    this.$offscreenInput()
      .off(`focus.${this.elementId}`)
      .off(`blur.${this.elementId}`)
      .off(`keydown.${this.elementId}`);

    this.$filterInput().off(`keydown.${this.elementId}`);
  },

  selectHighlightedRow(event) {
    const $highlightedRow = this.$highlightedRow();

    if ($highlightedRow.length === 1) {
      this.$highlightedRow().trigger("click");
      this.$offscreenInput().focus();
      event.preventDefault();
    }
  },

  didInsertElement() {
    this._super();

    $(document).on(`click.select-box-kit-${this.elementId}`, e => {
      const node = e.target;
      const $outside = $(`.select-box-kit#${this.elementId}`);
      $outside.each((i, outNode) => {
        if (outNode.contains(node)) { return; }
        this.clickOutside(event);
      });
    });

    this.$offscreenInput()
      .on(`blur.${this.elementId}`, () => {
        if (this.get("isExpanded") === false && this.get("isFocused") === true) {
          this.close();
        }
      })
      .on(`focus.${this.elementId}`, () => {
        this.set("isFocused", true);
      })
      .on(`keydown.${this.elementId}`, (event) => {
        const keyCode = event.keyCode || event.which;

        switch (keyCode) {
          case this.specialKeys.UP:
          case this.specialKeys.DOWN:
            if (this.get("isExpanded") === false) {
              this.set("isExpanded", true);
            }

            Ember.run.schedule("actions", () => {
              this._handleArrowKey(keyCode);
            });

            this._killEvent(event);

            return;
          case this.specialKeys.ENTER:
            if (this.get("isExpanded") === false) {
              this.set("isExpanded", true);
            } else {
              this.send("onSelect", this.$highlightedRow().data("value"));
            }

            this._killEvent(event);

            return;
          case this.specialKeys.TAB:
            if (this.get("isExpanded") === false) {
              return true;
            } else {
              this.send("onSelect", this.$highlightedRow().data("value"));
              return;
            }
          case this.specialKeys.ESC:
            this.close();
            this._killEvent(event);
            return;
          case this.specialKeys.BACKSPACE:
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
      .on(`keydown.${this.elementId}`, (event) => {
        const keyCode = event.keyCode || event.which;

        if ([
            this.specialKeys.RIGHT,
            this.specialKeys.LEFT,
            this.specialKeys.BACKSPACE
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
    this.send("onHighlight", $highlightableRow.data("value"));

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
    return Object.values(this.specialKeys).includes(keyCode);
  },
});
