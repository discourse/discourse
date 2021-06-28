import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  lastScrollPosition: 0,
  ticking: false,
  topHorizontalScrollBar: null,
  tableContainer: null,

  didRender() {
    this._super(...arguments);
    this.set(
      "tableContainer",
      this.element.querySelector(".directory-table-container")
    );
    if (
      this.tableContainer.getBoundingClientRect().bottom < window.innerHeight
    ) {
      // Bottom of the table is visible. Return and don't show top scrollbar
      return;
    }

    this.set(
      "topHorizontalScrollBar",
      this.element.querySelector(".directory-table-top-scroll")
    );
    const fakeContent = this.topHorizontalScrollBar.querySelector(
      ".directory-table-top-scroll-fake-content"
    );
    const table = this.tableContainer.querySelector(".directory-table");
    fakeContent.style.width = `${table.offsetWidth}px`;
    fakeContent.style.height = "1px";

    this.tableContainer.addEventListener("scroll", this.onBottomScroll);
    this.topHorizontalScrollBar.addEventListener("scroll", this.onTopScroll);

    // Set active header might have already scrolled the tableContainer.
    // Call onHorizontalScroll manually to scroll the topHorizontalScrollBar
    this.onHorizontalScroll(this.tableContainer, this.topHorizontalScrollBar);
  },

  @action
  onTopScroll() {
    this.onHorizontalScroll(this.topHorizontalScrollBar, this.tableContainer);
  },

  @action
  onBottomScroll() {
    this.onHorizontalScroll(this.tableContainer, this.topHorizontalScrollBar);
  },

  @action
  onHorizontalScroll(primary, replica) {
    if (this.lastScrollPosition === primary.scrollLeft) {
      return;
    }

    this.set("lastScrollPosition", primary.scrollLeft);

    if (!this.ticking) {
      window.requestAnimationFrame(() => {
        replica.scrollLeft = this.lastScrollPosition;
        this.set("ticking", false);
      });

      this.set("ticking", true);
    }
  },

  willDestoryElement() {
    this.tableContainer.removeEventListener("scroll", this.onBottomScroll);
    this.topHorizontalScrollBar.removeEventListener("scroll", this.onTopScroll);
  },

  @action
  setActiveHeader(header) {
    // After render, scroll table left to ensure the order by column is visible
    const tableContainer = this.element.querySelector(
      ".directory-table-container"
    );

    const scrollPixels =
      header.offsetLeft + header.offsetWidth + 10 - tableContainer.offsetWidth;

    if (scrollPixels > 0) {
      tableContainer.scrollLeft = scrollPixels;
    }
  },
});
