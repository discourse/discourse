import { registerDestructor } from "@ember/destroyable";
import { cancel, throttle } from "@ember/runloop";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";
import firstVisibleMessageId from "discourse/plugins/chat/discourse/helpers/first-visible-message-id";

const UP = "up";
const DOWN = "down";

export default class ChatScrollableList extends Modifier {
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, [options]) {
    this.element = element;
    this.options = options;

    this.lastScrollTop = this.computeInitialScrollTop();

    this.element.addEventListener("scroll", this.handleScroll, {
      passive: true,
    });
    // listen for wheel events to detect scrolling even when at the top or bottom
    this.element.addEventListener("wheel", this.handleWheel, {
      passive: true,
    });

    this.throttleComputeScroll();
  }

  @bind
  handleScroll() {
    this.throttleComputeScroll();
  }

  @bind
  handleWheel() {
    this.throttleComputeScroll();
  }

  @bind
  computeScroll() {
    const scrollTop = this.element.scrollTop;
    this.options.onScroll?.(this.computeState());
    this.lastScrollTop = scrollTop;
  }

  throttleComputeScroll() {
    cancel(this.scrollTimer);
    this.throttleTimer = throttle(this, this.computeScroll, 50, true);
    this.scrollTimer = discourseLater(() => {
      this.options.onScrollEnd?.(
        Object.assign(this.computeState(), {
          firstVisibleId: firstVisibleMessageId(this.element),
        })
      );
    }, this.options.delay || 250);
  }

  cleanup() {
    cancel(this.scrollTimer);
    cancel(this.throttleTimer);
    this.element.removeEventListener("scroll", this.handleScroll);
    this.element.removeEventListener("wheel", this.handleWheel);
  }

  computeState() {
    const direction = this.computeScrollDirection();
    const distanceToBottom = this.computeDistanceToBottom();
    const distanceToTop = this.computeDistanceToTop();
    return {
      up: direction === UP,
      down: direction === DOWN,
      distanceToBottom,
      distanceToTop,
      atBottom: distanceToBottom.pixels <= 1,
      atTop: distanceToTop.pixels <= 1,
    };
  }

  computeInitialScrollTop() {
    if (this.options.reverse) {
      return this.element.scrollHeight - this.element.clientHeight;
    } else {
      return this.element.scrollTop;
    }
  }

  computeScrollTop() {
    if (this.options.reverse) {
      return (
        this.element.scrollHeight -
        this.element.clientHeight -
        this.element.scrollTop
      );
    } else {
      return this.element.scrollTop;
    }
  }

  computeDistanceToTop() {
    let pixels;
    const height = this.element.scrollHeight - this.element.clientHeight;

    if (this.options.reverse) {
      pixels = height - Math.abs(this.element.scrollTop);
    } else {
      pixels = Math.abs(this.element.scrollTop);
    }

    return { pixels, percentage: Math.round((pixels / height) * 100) };
  }

  computeDistanceToBottom() {
    let pixels;
    const height = this.element.scrollHeight - this.element.clientHeight;

    if (this.options.reverse) {
      pixels = -this.element.scrollTop;
    } else {
      pixels = height - Math.abs(this.element.scrollTop);
    }

    return { pixels, percentage: Math.round((pixels / height) * 100) };
  }

  computeScrollDirection() {
    if (this.element.scrollTop === this.lastScrollTop) {
      return null;
    }

    return this.element.scrollTop < this.lastScrollTop ? UP : DOWN;
  }
}
