export default Ember.Mixin.create({
  willDestroyElement() {
    this._super();

    this.$offscreenInput()
      .off(`focus.${this.elementId}`)
      .off(`keydown.${this.elementId}`);

    this.$filterInput()
      .off(
        `blur.${this.elementId}`,
        `keydown.${this.elementId}`
      );
  },

  didInsertElement() {
    this._super();

    this.$offscreenInput()
      .on(`focus.${this.elementId}`, () => this.onFocusOffscreenInput())
      .on(`keydown.${this.elementId}`, (event) => {
        const keyCode = event.keyCode || event.which;

        if (keyCode === 27) {
          this.close();
          return false;
        }

        if (keyCode === 9) {
          this.close();
          this.$filterInput().focus();
          return true;
        }

        this.set("isExpanded", true);

        // when using arrow down/up make sure we expand
        // and set focus in filter, and propagate event to filter
        if (keyCode === 38 || keyCode === 40) {
          this.$filterInput().focus().trigger(event);
          return false;
        }

        this.set("filter", String.fromCharCode(keyCode));

        this.$filterInput().focus();
      });

    this.$filterInput()
      .on(`blur.${this.elementId}`, () => this.close() )
      .on(`keydown.${this.elementId}`, (event) => {
        const keyCode = event.keyCode || event.which;

        if (keyCode === 27) {
          this.close();
          return false;
        }

        if (keyCode === 9 && this.get("filter") === "") {
          this.close();
          return true;
        }

        if (keyCode === 38 || keyCode === 40) {
          event.preventDefault();
          this._handleArrowKey(keyCode);
          return false;
        }

        if ((keyCode === 13 || keyCode === 9) && this.$highlightedRow().length === 1) {
          this.send("onSelect", this.$highlightedRow().data("value"));
          this.$offscreenInput().focus();
          return false;
        }

        if (this.get("filterIsHidden") === true) {
          return false;
        } else {
          return true;
        }
      });
  },

  _handleArrowKey(keyCode) {
    if (this.$highlightedRow().length === 0) {
      if (this.$selectedRow().length === 0) {
        this.send("onHighlight", this.$rows().eq(0).data("value"));
      } else {
        this.send("onHighlight", this.$selectedRow().data("value"));
      }
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

  _handleDownArrow() {
    const $rows = this.$rows();
    const currentIndex = $rows.index(this.$highlightedRow());

    let nextIndex = 0;

    if (currentIndex < 0) {
      nextIndex = 0;
    } else if (currentIndex + 1 < $rows.length) {
      nextIndex = currentIndex + 1;
    }

    this._rowSelection($rows, nextIndex);
  },

  _handleUpArrow() {
    const $rows = this.$rows();
    const currentIndex = $rows.index(this.$highlightedRow());

    let nextIndex = 0;

    if (currentIndex < 0) {
      nextIndex = 0;
    } else if (currentIndex - 1 < $rows.length) {
      nextIndex = currentIndex - 1;
    }

    this._rowSelection($rows, nextIndex);
  },

  _rowSelection($rows, nextIndex) {
    const highlightableValue = $rows.eq(nextIndex).data("value");
    const $highlightableRow = this.$findRowByValue(highlightableValue);
    this.send("onHighlight", highlightableValue);

    Ember.run.schedule("afterRender", () => {
      if ($highlightableRow.length === 0) { return; }

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
  }
});
