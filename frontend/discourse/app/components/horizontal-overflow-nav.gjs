import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import onResize from "discourse/modifiers/on-resize";

export default class HorizontalOverflowNav extends Component {
  @service site;

  @tracked hasScroll;
  @tracked hideRightScroll = false;
  @tracked hideLeftScroll = true;
  scrollInterval;

  @bind
  scrollToActive(element) {
    const activeElement = element.querySelector("a.active");

    activeElement?.scrollIntoView({
      block: "nearest",
      inline: "center",
    });
  }

  @bind
  onResize(entries) {
    if (this.site.mobileView) {
      return;
    }

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
    if (this.site.mobileView) {
      return;
    }

    this.watchScroll(event.target);
  }

  watchScroll(element) {
    const { scrollWidth, scrollLeft, offsetWidth } = element;

    // Check if the content overflows
    this.hasScroll = scrollWidth > offsetWidth;

    // Ensure the right arrow disappears only when fully scrolled
    if (scrollWidth - scrollLeft - offsetWidth <= 2) {
      this.hideRightScroll = true;
      clearInterval(this.scrollInterval);
    } else {
      this.hideRightScroll = false;
    }

    // Ensure the left arrow disappears only when fully scrolled to the start
    if (scrollLeft <= 2) {
      this.hideLeftScroll = true;
      clearInterval(this.scrollInterval);
    } else {
      this.hideLeftScroll = false;
    }
  }

  @bind
  scrollDrag(event) {
    if (this.site.mobileView || !this.hasScroll) {
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
        {{didInsert this.scrollToActive}}
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
