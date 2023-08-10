import Modifier from "ember-modifier";
import { inject as service } from "@ember/service";
import { registerDestructor } from "@ember/destroyable";
import { bind } from "discourse-common/utils/decorators";
import {
  addWidgetCleanCallback,
  removeWidgetCleanCallback,
} from "discourse/components/mount-widget";
import { headerOffset } from "discourse/lib/offset-calculator";
import { schedule } from "@ember/runloop";

const STICKY_CLASS = "sticky-avatar";
const TOPIC_POST_SELECTOR = ".post-stream .topic-post";

export default class StickyAvatars extends Modifier {
  @service site;
  @service appEvents;

  element;
  intersectionObserver;
  direction = "⬇️";
  prevOffset = -1;

  constructor() {
    super(...arguments);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element) {
    if (this.site.mobileView || !("IntersectionObserver" in window)) {
      return;
    }

    this.element = element;

    this.appEvents.on(
      "topic:current-post-scrolled",
      this,
      this._handlePostNodes
    );
    this.appEvents.on("topic:scrolled", this, this._handleScroll);
    this.appEvents.on(
      "page:topic-loaded",
      this,
      this._initIntersectionObserver
    );

    addWidgetCleanCallback("post-stream", this._clearIntersectionObserver);
  }

  cleanup() {
    if (this.site.mobileView || !("IntersectionObserver" in window)) {
      return;
    }

    this.appEvents.off(
      "topic:current-post-scrolled",
      this,
      this._handlePostNodes
    );
    this.appEvents.off("topic:scrolled", this, this._handleScroll);
    this.appEvents.off(
      "page:topic-loaded",
      this,
      this._initIntersectionObserver
    );

    removeWidgetCleanCallback("post-stream", this._clearIntersectionObserver);
  }

  @bind
  _handleScroll(offset) {
    if (offset <= 0) {
      this.direction = "⬇️";
      this.element
        .querySelectorAll(`${TOPIC_POST_SELECTOR}.${STICKY_CLASS}`)
        .forEach((node) => node.classList.remove(STICKY_CLASS));
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
      this.element.querySelectorAll(TOPIC_POST_SELECTOR).forEach((postNode) => {
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
      const offset = headerOffset();
      const headerOffsetInPx = offset <= 0 ? "0px" : `-${offset}px`;

      this.intersectionObserver = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (!entry.isIntersecting || entry.intersectionRatio === 1) {
              entry.target.classList.remove(STICKY_CLASS);
              return;
            }

            const postContentHeight =
              entry.target.querySelector(".contents")?.clientHeight;
            if (
              this.direction === "⬆️" ||
              postContentHeight > window.innerHeight - offset
            ) {
              entry.target.classList.add(STICKY_CLASS);
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
