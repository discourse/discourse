import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { measureScrollBounds } from "discourse/lib/scroll-utils";
import { isDocumentRTL } from "discourse/lib/text-direction";
import onResize from "discourse/modifiers/on-resize";

export default class HorizontalOverflowNav extends Component {
  @tracked hasScroll;
  @tracked hideRightScroll = false;
  @tracked hideLeftScroll = true;
  scrollInterval;
  #minScrollLeft = 0;
  #maxScrollLeft = 0;

  @bind
  setup(element) {
    this.#updateScrollBounds(element);
    this.scrollToActive(element);
    this.watchScroll(element);

    const observer = new MutationObserver(() => {
      this.#updateScrollBounds(element);
      this.watchScroll(element);
    });
    observer.observe(element, { childList: true });
    registerDestructor(this, () => observer.disconnect());
  }

  @bind
  scrollToActive(element) {
    const activeElement = element.querySelector("a.active");

    activeElement?.scrollIntoView({
      block: "nearest",
      inline: "center",
      container: "nearest",
    });
  }

  @bind
  onResize(entries) {
    const element = entries[0].target;
    this.#updateScrollBounds(element);
    this.watchScroll(element);
  }

  @bind
  stopScroll() {
    clearInterval(this.scrollInterval);
  }

  @bind
  onScroll(event) {
    this.watchScroll(event.target);
  }

  #updateScrollBounds(element) {
    const { min, max } = measureScrollBounds(element);
    this.#minScrollLeft = min;
    this.#maxScrollLeft = max;
  }

  watchScroll(element) {
    this.hasScroll = element.scrollWidth > element.offsetWidth;

    if (!this.hasScroll) {
      this.hideLeftScroll = true;
      this.hideRightScroll = true;
      clearInterval(this.scrollInterval);
      return;
    }

    const atMin = element.scrollLeft - this.#minScrollLeft <= 2;
    const atMax = this.#maxScrollLeft - element.scrollLeft <= 2;

    if (isDocumentRTL()) {
      // rtlcss swaps the physical positions of left/right buttons,
      // so we swap which condition controls which button
      this.hideLeftScroll = atMax;
      this.hideRightScroll = atMin;
    } else {
      this.hideLeftScroll = atMin;
      this.hideRightScroll = atMax;
    }

    if (atMin || atMax) {
      clearInterval(this.scrollInterval);
    }
  }

  @bind
  scrollDrag(event) {
    if (!this.hasScroll) {
      return;
    }

    event.preventDefault();

    const navPills = event.target.closest(".nav-pills");

    const position = {
      left: navPills.scrollLeft, // current scroll
      x: event.clientX, // mouse position
    };

    const mouseDragScroll = function (e) {
      let mouseChange = e.clientX - position.x;
      navPills.scrollLeft = position.left - mouseChange;
    };

    navPills.querySelectorAll("a").forEach((a) => {
      a.style.cursor = "grabbing";
    });

    const removeDragScroll = function () {
      document.removeEventListener("mousemove", mouseDragScroll);
      navPills.querySelectorAll("a").forEach((a) => {
        a.style.cursor = "pointer";
      });
    };

    document.addEventListener("mousemove", mouseDragScroll);
    document.addEventListener("mouseup", removeDragScroll, { once: true });
  }

  @action
  horizontalScroll(event) {
    // Do nothing if it is not left mousedown
    if (event.which !== 1) {
      return;
    }

    const scrollSpeed = 175;
    let scrollDirection = 1;
    let siblingTarget = event.target.previousElementSibling;

    if (event.target.dataset.direction === "left") {
      scrollDirection = -1;
      siblingTarget = event.target.nextElementSibling;
    }

    if (isDocumentRTL()) {
      scrollDirection *= -1;
    }

    const delta = scrollSpeed * scrollDirection;
    siblingTarget.scrollLeft += delta;

    this.scrollInterval = setInterval(function () {
      siblingTarget.scrollLeft += delta;
    }, 50);
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding }}
    {{! template-lint-disable no-invalid-interactive }}

    <nav
      class="horizontal-overflow-nav {{if this.hasScroll 'has-scroll'}}"
      aria-label={{@ariaLabel}}
    >
      {{#if this.hasScroll}}
        <a
          role="button"
          {{on "mousedown" this.horizontalScroll}}
          {{on "mouseup" this.stopScroll}}
          {{on "mouseleave" this.stopScroll}}
          data-direction="left"
          class={{concatClass
            "horizontal-overflow-nav__scroll-left"
            (if this.hideLeftScroll "disabled")
          }}
        >
          {{icon "chevron-left"}}
        </a>
      {{/if}}

      <ul
        {{onResize this.onResize}}
        {{on "scroll" this.onScroll}}
        {{didInsert this.setup}}
        {{on "mousedown" this.scrollDrag}}
        class="nav-pills action-list {{@className}}"
        ...attributes
      >
        {{yield}}
      </ul>

      {{#if this.hasScroll}}
        <a
          role="button"
          {{on "mousedown" this.horizontalScroll}}
          {{on "mouseup" this.stopScroll}}
          {{on "mouseleave" this.stopScroll}}
          class={{concatClass
            "horizontal-overflow-nav__scroll-right"
            (if this.hideRightScroll "disabled")
          }}
        >
          {{icon "chevron-right"}}
        </a>
      {{/if}}
    </nav>
  </template>
}
