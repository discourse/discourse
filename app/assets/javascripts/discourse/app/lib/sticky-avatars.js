import { addWidgetCleanCallback } from "discourse/components/mount-widget";
import Site from "discourse/models/site";
import { bind } from "discourse-common/utils/decorators";
import { schedule } from "@ember/runloop";

export default class StickyAvatars {
  stickyClass = "sticky-avatar";
  topicPostSelector = "#topic .post-stream .topic-post";
  intersectionObserver = null;
  direction = "⬇️";
  prevOffset = -1;

  static init(container) {
    return new this(container).init();
  }

  constructor(container) {
    this.container = container;
  }

  init() {
    if (Site.currentProp("mobileView") || !("IntersectionObserver" in window)) {
      return;
    }

    const appEvents = this.container.lookup("service:app-events");
    appEvents.on("topic:current-post-scrolled", this._handlePostNodes);
    appEvents.on("topic:scrolled", this._handleScroll);
    appEvents.on("page:topic-loaded", this._initIntersectionObserver);

    addWidgetCleanCallback("post-stream", this._clearIntersectionObserver);

    return this;
  }

  destroy() {
    this.container = null;
  }

  @bind
  _handleScroll(offset) {
    if (offset <= 0) {
      this.direction = "⬇️";
      document
        .querySelectorAll(`${this.topicPostSelector}.${this.stickyClass}`)
        .forEach((node) => node.classList.remove(this.stickyClass));
    } else if (offset > this.prevOffset) {
      this.direction = "⬇️";
    } else {
      this.direction = "⬆️";
    }
    this.prevOffset = offset;
  }

  @bind
  _handlePostNodes() {
    this._clearIntersectionObserver();
    this._initIntersectionObserver();

    schedule("afterRender", () => {
      document.querySelectorAll(this.topicPostSelector).forEach((postNode) => {
        this.intersectionObserver.observe(postNode);

        const topicAvatarNode = postNode.querySelector(".topic-avatar");
        if (!topicAvatarNode || !postNode.querySelector("#post_1")) {
          return;
        }

        const topicMapNode = postNode.querySelector(".topic-map");
        if (!topicMapNode) {
          return;
        }
        topicAvatarNode.style.marginBottom = `${topicMapNode.clientHeight}px`;
      });
    });
  }

  @bind
  _initIntersectionObserver() {
    schedule("afterRender", () => {
      const headerOffset =
        parseInt(document.body.style.getPropertyValue("--header-offset"), 10) ||
        0;
      const headerHeight = Math.max(headerOffset, 0);

      this.intersectionObserver = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (!entry.isIntersecting || entry.intersectionRatio === 1) {
              entry.target.classList.remove(this.stickyClass);
              return;
            }

            const postContentHeight = entry.target.querySelector(".contents")
              ?.clientHeight;
            if (
              this.direction === "⬆️" ||
              postContentHeight > window.innerHeight - headerHeight
            ) {
              entry.target.classList.add(this.stickyClass);
            }
          });
        },
        { threshold: [0.0, 1.0], rootMargin: `-${headerHeight}px 0px 0px 0px` }
      );
    });
  }

  @bind
  _clearIntersectionObserver() {
    this.intersectionObserver?.disconnect();
    this.intersectionObserver = null;
  }
}
