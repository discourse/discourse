import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { isDocumentRTL } from "discourse/lib/text-direction";
import onResize from "discourse/modifiers/on-resize";

export default class HorizontalOverflowNav extends Component {
  @tracked hasScroll;
  @tracked hideRightScroll = false;
  @tracked hideLeftScroll = true;
  scrollInterval;

  @bind
  setup(element) {
    this.scrollToActive(element);

    const observer = new MutationObserver(() => this.watchScroll(element));
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
    this.watchScroll(element);
    this.hasScroll = element.scrollWidth > element.offsetWidth;
  }

  @bind
  stopScroll() {
    clearInterval(this.scrollInterval);
  }

  @bind
  onScroll(event) {
    this.watchScroll(event.target);
  }

  watchScroll(element) {
    const { scrollWidth, scrollLeft, offsetWidth } = element;

    // Check if the content overflows
    this.hasScroll = scrollWidth > offsetWidth;

    if (!this.hasScroll) {
      this.hideLeftScroll = true;
      this.hideRightScroll = true;
      clearInterval(this.scrollInterval);
      return;
    }

    const atStart = Math.abs(scrollLeft) <= 2;
    const atEnd = scrollWidth - Math.abs(scrollLeft) - offsetWidth <= 2;

    // Buttons stay in physical positions (rtl:ignore in CSS), but in RTL
    // the scroll direction is reversed, so swap which button hides
    if (isDocumentRTL()) {
      this.hideLeftScroll = atEnd;
      this.hideRightScroll = atStart;
    } else {
      this.hideLeftScroll = atStart;
      this.hideRightScroll = atEnd;
    }

    if (atStart || atEnd) {
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

    let scrollSpeed = 175;
    let siblingTarget = event.target.previousElementSibling;

    if (event.target.dataset.direction === "left") {
      scrollSpeed = scrollSpeed * -1;
      siblingTarget = event.target.nextElementSibling;
    }

    siblingTarget.scrollLeft += scrollSpeed;

    this.scrollInterval = setInterval(function () {
      siblingTarget.scrollLeft += scrollSpeed;
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
