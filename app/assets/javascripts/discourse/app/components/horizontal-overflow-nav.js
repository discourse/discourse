import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";

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
}
