import Component from "@glimmer/component";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class HorizontalOverflowNav extends Component {
  @service site;
  @tracked hasScroll;
  @tracked hideRightScroll = false;
  @tracked hideLeftScroll = true;
  scrollInterval;

  @bind
  scrollToActive() {
    const activeElement = document.querySelector(
      ".user-navigation-secondary a.active"
    );

    activeElement?.scrollIntoView({
      block: "nearest",
      inline: "center",
    });
  }

  @bind
  checkScroll(element) {
    if (this.site.mobileView) {
      return;
    }

    this.watchScroll(element);
    return (this.hasScroll =
      element.target.scrollWidth > element.target.offsetWidth);
  }

  @bind
  stopScroll() {
    clearInterval(this.scrollInterval);
  }

  @bind
  watchScroll(element) {
    if (this.site.mobileView) {
      return;
    }

    if (
      element.target.offsetWidth + element.target.scrollLeft ===
      element.target.scrollWidth
    ) {
      this.hideRightScroll = true;
      clearInterval(this.scrollInterval);
    } else {
      this.hideRightScroll = false;
    }

    if (element.target.scrollLeft === 0) {
      this.hideLeftScroll = true;
      clearInterval(this.scrollInterval);
    } else {
      this.hideLeftScroll = false;
    }
  }

  @action
  horizScroll(element) {
    let scrollSpeed = 100;
    let siblingTarget = element.target.previousElementSibling;

    if (element.target.dataset.direction === "left") {
      scrollSpeed = scrollSpeed * -1;
      siblingTarget = element.target.nextElementSibling;
    }

    this.scrollInterval = setInterval(function () {
      siblingTarget.scrollLeft += scrollSpeed;
    }, 50);

    element.target.addEventListener("mouseup", this.stopScroll);
    element.target.addEventListener("mouseleave", this.stopScroll);
  }
}
