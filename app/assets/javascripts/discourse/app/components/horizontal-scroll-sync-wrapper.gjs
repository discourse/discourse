import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { modifier } from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import onResize from "discourse/modifiers/on-resize";

export default class HorizontalScrollSyncWrapper extends Component {
  scrollableElement;
  topHorizontalScrollBar;
  fakeScrollContent;
  intersectionObserver;
  lastScrollLeft = 0;

  setup = modifier((containerElement) => {
    // Always use the content wrapper as the scrollable element
    this.scrollableElement = containerElement.querySelector(
      ".horizontal-scroll-sync__content"
    );

    this.topHorizontalScrollBar = containerElement.querySelector(
      ".horizontal-scroll-sync__top-scroll"
    );
    this.fakeScrollContent = containerElement.querySelector(
      ".horizontal-scroll-sync__fake-content"
    );

    if (this.scrollableElement) {
      this.scrollableElement.addEventListener(
        "scroll",
        this.handleScrollableElementScroll,
        { passive: true }
      );
    }

    this.setupObserver();
    this.syncScrollWidth();

    return () => {
      if (this.scrollableElement) {
        this.scrollableElement.removeEventListener(
          "scroll",
          this.handleScrollableElementScroll
        );
      }
      this.cleanup();
    };
  });

  @bind
  syncScrollPosition(source, target) {
    const newScrollLeft = source.scrollLeft;

    // need to check if content position has actually changed
    // to avoid getting stuck in a loop on position sync
    if (Math.abs(newScrollLeft - this.lastScrollLeft) > 1) {
      this.lastScrollLeft = newScrollLeft;
      requestAnimationFrame(() => {
        target.scrollLeft = newScrollLeft;
      });
    }
  }

  @bind
  handleScrollableElementScroll() {
    this.syncScrollPosition(
      this.scrollableElement,
      this.topHorizontalScrollBar
    );
  }

  @bind
  handleTopScrollBarScroll() {
    this.syncScrollPosition(
      this.topHorizontalScrollBar,
      this.scrollableElement
    );
  }

  @bind
  setupObserver() {
    if (!this.scrollableElement || !this.fakeScrollContent) {
      return;
    }

    this.intersectionObserver = new IntersectionObserver(
      (entries) => {
        const entry = entries[0];
        if (entry.boundingClientRect.bottom < entry.rootBounds.height) {
          // bottom is visible, hide the top scrollbar
          this.fakeScrollContent.style.height = "0";
        } else {
          this.syncScrollWidth();
        }
      },
      {
        root: null, // viewport
        threshold: 0,
      }
    );

    this.intersectionObserver.observe(this.scrollableElement);
  }

  @bind
  syncScrollWidth() {
    if (this.scrollableElement && this.fakeScrollContent) {
      this.fakeScrollContent.style.width = `${this.scrollableElement.scrollWidth}px`;
      this.fakeScrollContent.style.height = "12px"; // needs height to show the scrollbar
    }
  }

  @bind
  cleanup() {
    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect();
      this.intersectionObserver = null;
    }
  }

  <template>
    <div {{this.setup}} class="horizontal-scroll-sync__container" ...attributes>
      <div
        {{on "scroll" this.handleTopScrollBarScroll passive=true}}
        class="horizontal-scroll-sync__top-scroll"
      >
        <div class="horizontal-scroll-sync__fake-content"></div>
      </div>

      <div
        {{onResize this.syncScrollWidth}}
        class="horizontal-scroll-sync__content"
      >
        {{yield}}
      </div>
    </div>
  </template>
}
