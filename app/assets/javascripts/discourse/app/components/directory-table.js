import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  lastScrollPosition: 0,
  ticking: false,
  _topHorizontalScrollBar: null,
  _table: null,
  _fakeScrollContent: null,

  didInsertElement() {
    this._super(...arguments);
    this.setProperties({
      _topHorizontalScrollBar: this.element.querySelector(
        ".directory-table-top-scroll"
      ),
      _fakeScrollContent: this.element.querySelector(
        ".directory-table-top-scroll-fake-content"
      ),
      _table: this.element.querySelector(".directory-table"),
      _columnCount: this.showTimeRead
        ? this.attrs.columns.value.length + 1
        : this.attrs.columns.value.length,
    });

    this._table.style.gridTemplateColumns = `minmax(13em, 3fr) repeat(${this._columnCount}, minmax(min-content, 1fr))`;

    this._table.addEventListener("scroll", this.onBottomScroll);
    this._topHorizontalScrollBar.addEventListener("scroll", this.onTopScroll);

    // Set active header might have already scrolled the _table.
    // Call onHorizontalScroll manually to scroll the _topHorizontalScrollBar
    this.onResize();
    this.onHorizontalScroll(this._tableContainer, this._topHorizontalScrollBar);
    window.addEventListener("resize", this.onResize);
  },

  @action
  onResize() {
    if (this._table.getBoundingClientRect().bottom < window.innerHeight) {
      // Bottom of the table is visible. Hide the scrollbar
      this._fakeScrollContent.style.height = 0;
    } else {
      this._fakeScrollContent.style.width = `${this._table.scrollWidth}px`;
      this._fakeScrollContent.style.height = "1px";
    }
  },

  @action
  onTopScroll() {
    this.onHorizontalScroll(this._topHorizontalScrollBar, this._table);
  },

  @action
  onBottomScroll() {
    this.onHorizontalScroll(this._table, this._topHorizontalScrollBar);
  },

  @action
  onHorizontalScroll(primary, replica) {
    if (
      this.isDestroying ||
      this.isDestroyed ||
      this.lastScrollPosition === primary?.scrollLeft
    ) {
      return;
    }

    this.set("lastScrollPosition", primary?.scrollLeft);

    if (!this.ticking) {
      window.requestAnimationFrame(() => {
        if (!this.isDestroying && !this.isDestroyed) {
          replica.scrollLeft = this.lastScrollPosition;
          this.set("ticking", false);
        }
      });

      this.set("ticking", true);
    }
  },

  willDestroyElement() {
    this._table.removeEventListener("scroll", this.onBottomScroll);
    this._topHorizontalScrollBar.removeEventListener(
      "scroll",
      this.onTopScroll
    );
    window.removeEventListener("resize", this.onResize);
  },

  @action
  setActiveHeader(header) {
    // After render, scroll table left to ensure the order by column is visible
    if (!this._table) {
      this.set("_table", document.querySelector(".directory-table"));
    }
    const scrollPixels =
      header.offsetLeft + header.offsetWidth + 10 - this._table.offsetWidth;

    if (scrollPixels > 0) {
      this._table.scrollLeft = scrollPixels;
    }
  },
});
