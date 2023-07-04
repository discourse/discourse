import { addWidgetCleanCallback } from "discourse/components/mount-widget";
import Site from "discourse/models/site";
import { bind } from "discourse-common/utils/decorators";
import { headerOffset } from "discourse/lib/offset-calculator";
import { getOwner, setOwner } from "@ember/application";
import { schedule } from "@ember/runloop";

export default class StickyAvatars {
  static init(owner) {
    return new this(owner).init();
  }

  stickyClass = "sticky-avatar";
  topicPostSelector = "#topic .post-stream .topic-post";
  intersectionObserver = null;
  direction = "⬇️";
  prevOffset = -1;

  constructor(owner) {
    setOwner(this, owner);
  }

  init() {
    if (Site.currentProp("mobileView") || !("IntersectionObserver" in window)) {
      return;
    }

    const appEvents = getOwner(this).lookup("service:app-events");
    appEvents.on("topic:current-post-scrolled", this._handlePostNodes);
    appEvents.on("topic:scrolled", this._handleScroll);
    appEvents.on("page:topic-loaded", this._initIntersectionObserver);

    addWidgetCleanCallback("post-stream", this._clearIntersectionObserver);

    return this;
  }

  destroy() {}

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
      const headerOffsetInPx =
        headerOffset() <= 0 ? "0px" : `-${headerOffset()}px`;

      this.intersectionObserver = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (!entry.isIntersecting || entry.intersectionRatio === 1) {
              entry.target.classList.remove(this.stickyClass);
              return;
            }

            const postContentHeight =
              entry.target.querySelector(".contents")?.clientHeight;
            if (
              this.direction === "⬆️" ||
              postContentHeight > window.innerHeight - headerOffset()
            ) {
              entry.target.classList.add(this.stickyClass);
            }
          });
        },
        {
          threshold: [0.0, 1.0],
          rootMargin: `${headerOffsetInPx} 0px 0px 0px`,
        }
      );
    });
  }

  @bind
  _clearIntersectionObserver() {
    this.intersectionObserver?.disconnect();
    this.intersectionObserver = null;
  }
}
