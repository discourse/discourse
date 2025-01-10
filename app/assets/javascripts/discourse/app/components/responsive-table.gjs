import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { modifier } from "ember-modifier";
import concatClass from "discourse/helpers/concat-class";
import onResize from "discourse/modifiers/on-resize";
import { bind } from "discourse-common/utils/decorators";

export default class ResponsiveTable extends Component {
  lastScrollPosition = 0;
  ticking = false;
  table;
  topHorizontalScrollBar;
  fakeScrollContent;

  setup = modifier((element) => {
    this.table = element.querySelector(".directory-table");
    this.topHorizontalScrollBar = element.querySelector(
      ".directory-table-top-scroll"
    );
    this.fakeScrollContent = element.querySelector(
      ".directory-table-top-scroll-fake-content"
    );

    this.checkScroll();
  });

  @bind
  checkScroll() {
    if (this.table.getBoundingClientRect().bottom < window.innerHeight) {
      // Bottom of the table is visible. Hide the scrollbar
      this.fakeScrollContent.style.height = 0;
    } else {
      this.fakeScrollContent.style.width = `${this.table.scrollWidth}px`;
      this.fakeScrollContent.style.height = "1px";
    }
  }

  @bind
  replicateScroll(from, to) {
    this.lastScrollPosition = from?.scrollLeft;

    if (!this.ticking) {
      window.requestAnimationFrame(() => {
        to.scrollLeft = this.lastScrollPosition;
        this.ticking = false;
      });

      this.ticking = true;
    }
  }

  <template>
    <div {{this.setup}} class="directory-table-container" ...attributes>
      <div
        {{on
          "scroll"
          (fn this.replicateScroll this.topHorizontalScrollBar this.table)
        }}
        class="directory-table-top-scroll"
      >
        <div class="directory-table-top-scroll-fake-content"></div>
      </div>

      <div
        {{didUpdate this.checkScroll}}
        {{onResize this.checkScroll}}
        {{on
          "scroll"
          (fn this.replicateScroll this.table this.topHorizontalScrollBar)
        }}
        role="table"
        aria-label={{@ariaLabel}}
        style={{@style}}
        class={{concatClass "directory-table" @className}}
      >
        <div class="directory-table__header">
          {{yield to="header"}}
        </div>

        <div class="directory-table__body">
          {{yield to="body"}}
        </div>
      </div>
    </div>
  </template>
}
