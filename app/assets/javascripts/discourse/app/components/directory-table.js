import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  lastScrollPosition: 0,
  ticking: false,
  _topHorizontalScrollBar: null,
  _tableContainer: null,
  _table: null,
  _fakeScrollContent: null,

  didInsertElement() {
    this._super(...arguments);
    this.setProperties({
      _tableContainer: this.element.querySelector(".directory-table-container"),
      _topHorizontalScrollBar: this.element.querySelector(
        ".directory-table-top-scroll"
      ),
      _fakeScrollContent: this.element.querySelector(
        ".directory-table-top-scroll-fake-content"
      ),
      _table: this.element.querySelector(".directory-table"),
    });

    this._tableContainer.addEventListener("scroll", this.onBottomScroll);
    this._topHorizontalScrollBar.addEventListener("scroll", this.onTopScroll);

    // Set active header might have already scrolled the _tableContainer.
    // Call onHorizontalScroll manually to scroll the _topHorizontalScrollBar
    this.onResize();
    this.onHorizontalScroll(this._tableContainer, this._topHorizontalScrollBar);
    window.addEventListener("resize", this.onResize);
  },

  @action
  onResize() {
    if (
      this._tableContainer.getBoundingClientRect().bottom < window.innerHeight
    ) {
      // Bottom of the table is visible. Hide the scrollbar
      this._fakeScrollContent.style.height = 0;
    } else {
      this._fakeScrollContent.style.width = `${this._table.offsetWidth}px`;
      this._fakeScrollContent.style.height = "1px";
    }
  },

  @action
  onTopScroll() {
    this.onHorizontalScroll(this._topHorizontalScrollBar, this._tableContainer);
  },

  @action
  onBottomScroll() {
    this.onHorizontalScroll(this._tableContainer, this._topHorizontalScrollBar);
  },

  @action
  onHorizontalScroll(primary, replica) {
    if (
      this.isDestroying ||
      this.isDestroyed ||
      this.lastScrollPosition === primary.scrollLeft
    ) {
      return;
    }

    this.set("lastScrollPosition", primary.scrollLeft);

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

  willDestoryElement() {
    this._tableContainer.removeEventListener("scroll", this.onBottomScroll);
    this._topHorizontalScrollBar.removeEventListener(
      "scroll",
      this.onTopScroll
    );
    window.removeEventListener("resize", this.onResize);
  },

  @action
  setActiveHeader(header) {
    // After render, scroll table left to ensure the order by column is visible
    if (!this._tableContainer) {
      this.set(
        "_tableContainer",
        document.querySelector(".directory-table-container")
      );
    }
    const scrollPixels =
      header.offsetLeft +
      header.offsetWidth +
      10 -
      this._tableContainer.offsetWidth;

    if (scrollPixels > 0) {
      this._tableContainer.scrollLeft = scrollPixels;
    }
  },
});
