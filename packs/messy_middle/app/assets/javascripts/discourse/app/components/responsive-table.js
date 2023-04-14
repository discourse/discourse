import Component from "@ember/component";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";

export default class ResponsiveTable extends Component {
  @tracked lastScrollPosition = 0;
  @tracked ticking = false;
  @tracked _table = document.querySelector(".directory-table");
  @tracked _topHorizontalScrollBar = document.querySelector(
    ".directory-table-top-scroll"
  );

  @bind
  checkScroll() {
    const _fakeScrollContent = document.querySelector(
      ".directory-table-top-scroll-fake-content"
    );

    if (this._table.getBoundingClientRect().bottom < window.innerHeight) {
      // Bottom of the table is visible. Hide the scrollbar
      _fakeScrollContent.style.height = 0;
    } else {
      _fakeScrollContent.style.width = `${this._table.scrollWidth}px`;
      _fakeScrollContent.style.height = "1px";
    }
  }

  @bind
  onTopScroll() {
    this.onHorizontalScroll(this._topHorizontalScrollBar, this._table);
  }

  @bind
  onBottomScroll() {
    this.onHorizontalScroll(this._table, this._topHorizontalScrollBar);
  }

  @bind
  onHorizontalScroll(primary, replica) {
    this.set("lastScrollPosition", primary?.scrollLeft);

    if (!this.ticking) {
      window.requestAnimationFrame(() => {
        replica.scrollLeft = this.lastScrollPosition;
        this.set("ticking", false);
      });

      this.set("ticking", true);
    }
  }
}
