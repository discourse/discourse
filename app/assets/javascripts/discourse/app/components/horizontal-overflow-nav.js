import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";

export default class HorizontalOverflowNav extends Component {
  @service site;
  @tracked hasScroll;
  @tracked hideRightScroll = false;
  @tracked hideLeftScroll = true;
  scrollInterval;

  @bind
  scrollToActive(entries) {
    const element = entries[0].target;
    const activeElement = element.querySelector("a.active");

    activeElement?.scrollIntoView({
      block: "nearest",
      inline: "center",
    });
  }

  @bind
  checkScroll(event) {
    if (this.site.mobileView) {
      return;
    }

    this.watchScroll(event);
    this.hasScroll = event.target.scrollWidth > event.target.offsetWidth;
  }

  @bind
  stopScroll() {
    clearInterval(this.scrollInterval);
  }

  @bind
  watchScroll(event) {
    if (this.site.mobileView) {
      return;
    }

    if (
      event.target.offsetWidth + event.target.scrollLeft ===
      event.target.scrollWidth
    ) {
      this.hideRightScroll = true;
      clearInterval(this.scrollInterval);
    } else {
      this.hideRightScroll = false;
    }

    if (event.target.scrollLeft === 0) {
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
